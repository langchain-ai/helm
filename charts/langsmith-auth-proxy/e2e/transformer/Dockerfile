FROM golang:1.23 AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY sample-ext-proc.go .
RUN CGO_ENABLED=0 go build -o /transformer ./sample-ext-proc.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /transformer /transformer
ENTRYPOINT ["/transformer"]
