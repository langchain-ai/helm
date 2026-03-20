// Sample ext_proc gRPC service for e2e testing.
//
// Implements envoy.service.ext_proc.v3.ExternalProcessor.
// Demonstrates header injection (read JWT, add Authorization) and
// request body transformation (OpenAI format -> custom format).
//
// Usage:
//
//	go run sample-ext-proc.go
//
// Requires the Envoy ext_proc proto Go package:
//
//	go get github.com/envoyproxy/go-control-plane/envoy/service/ext_proc/v3
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"strings"

	core "github.com/envoyproxy/go-control-plane/envoy/config/core/v3"
	ext_proc "github.com/envoyproxy/go-control-plane/envoy/service/ext_proc/v3"
	"google.golang.org/grpc"
)

type server struct {
	ext_proc.UnimplementedExternalProcessorServer
}

func (s *server) Process(stream ext_proc.ExternalProcessor_ProcessServer) error {
	for {
		req, err := stream.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}

		var resp *ext_proc.ProcessingResponse

		switch v := req.Request.(type) {
		case *ext_proc.ProcessingRequest_RequestHeaders:
			resp = handleRequestHeaders(v.RequestHeaders)
		case *ext_proc.ProcessingRequest_ResponseHeaders:
			resp = &ext_proc.ProcessingResponse{}
		case *ext_proc.ProcessingRequest_RequestBody:
			resp = handleRequestBody(v.RequestBody)
		case *ext_proc.ProcessingRequest_ResponseBody:
			resp = &ext_proc.ProcessingResponse{}
		default:
			resp = &ext_proc.ProcessingResponse{}
		}

		if err := stream.Send(resp); err != nil {
			return err
		}
	}
}

func handleRequestHeaders(headers *ext_proc.HttpHeaders) *ext_proc.ProcessingResponse {
	var jwtValue string
	for _, h := range headers.Headers.Headers {
		if strings.EqualFold(h.Key, "x-langsmith-llm-auth") {
			if len(h.RawValue) > 0 {
				jwtValue = string(h.RawValue)
			} else {
				jwtValue = h.Value
			}
			break
		}
	}

	resp := &ext_proc.ProcessingResponse{
		Response: &ext_proc.ProcessingResponse_RequestHeaders{
			RequestHeaders: &ext_proc.HeadersResponse{},
		},
	}

	if jwtValue != "" {
		log.Printf("Found JWT: %.40s...", jwtValue)
		headerResp := resp.GetRequestHeaders()
		headerResp.Response = &ext_proc.CommonResponse{
			HeaderMutation: &ext_proc.HeaderMutation{
				SetHeaders: []*core.HeaderValueOption{
					{
						Header: &core.HeaderValue{
							Key:      "Authorization",
							RawValue: []byte("Bearer fake-upstream-key"),
						},
					},
					{
						Header: &core.HeaderValue{
							Key:      "X-Ext-Proc-Applied",
							RawValue: []byte("true"),
						},
					},
				},
			},
		}
	}

	return resp
}

func handleRequestBody(body *ext_proc.HttpBody) *ext_proc.ProcessingResponse {
	resp := &ext_proc.ProcessingResponse{
		Response: &ext_proc.ProcessingResponse_RequestBody{
			RequestBody: &ext_proc.BodyResponse{},
		},
	}

	var original map[string]interface{}
	if err := json.Unmarshal(body.Body, &original); err != nil {
		log.Printf("Body transform failed, passing through: %v", err)
		return resp
	}

	log.Printf("Transforming request body: model=%v", original["model"])

	transformed := map[string]interface{}{
		"custom_model":    original["model"],
		"custom_messages": original["messages"],
		"metadata":        map[string]string{"source": "langsmith-ext-proc"},
	}

	newBody, err := json.Marshal(transformed)
	if err != nil {
		log.Printf("Body marshal failed: %v", err)
		return resp
	}

	bodyResp := resp.GetRequestBody()
	bodyResp.Response = &ext_proc.CommonResponse{
		BodyMutation: &ext_proc.BodyMutation{
			Mutation: &ext_proc.BodyMutation_Body{
				Body: newBody,
			},
		},
	}

	return resp
}

func main() {
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	ext_proc.RegisterExternalProcessorServer(s, &server{})

	fmt.Println("ext_proc sample listening on :50051")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
