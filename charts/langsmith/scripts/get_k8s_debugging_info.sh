#!/bin/bash

# We expect the namespace hosting all kubernetes resources to be passed as an argument to this script
FILTER_REGEX=""
FILTER_LABELS=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --namespace) NS="$2"; shift ;;
    --filter-regex) FILTER_REGEX="$2"; shift ;;
    --filter-labels) FILTER_LABELS="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

if [ -z "$NS" ]; then
  echo "Usage: $0 --namespace <namespace> [--filter-regex <pattern>] [--filter-labels <selector>]"
  echo ""
  echo "Examples:"
  echo "  $0 --namespace langchain --filter-regex '^(langsmith-|lg-|toolbox)'"
  echo "  $0 --namespace langchain --filter-labels 'app.kubernetes.io/instance=langsmith'"
  echo "  $0 --namespace langchain --filter-labels 'app.kubernetes.io/part-of=langgraph'"
  exit 1
fi

# Default regex filter for backward compatibility
if [ -z "$FILTER_REGEX" ] && [ -z "$FILTER_LABELS" ]; then
  FILTER_REGEX='^(langsmith-|lg-|toolbox)'
  echo "No filter specified. Using default regex filter: $FILTER_REGEX"
fi

DIR=/tmp/langchain-debugging-$(date +%Y%m%d%H%M%S)

echo "Starting to pull debugging info. Creating directory $DIR..."
mkdir -p "$DIR"

echo "Pulling summary of resources..."
if [ -n "$FILTER_LABELS" ]; then
  kubectl get all -n "$NS" -l "$FILTER_LABELS" -o wide > "$DIR/resources_summary.txt"
else
  kubectl get all -n "$NS" -o wide | grep -E "^(NAME|$FILTER_REGEX)" > "$DIR/resources_summary.txt"
fi

echo "Pulling details of all resources..."
if [ -n "$FILTER_LABELS" ]; then
  kubectl get all -n "$NS" -l "$FILTER_LABELS" -o yaml > "$DIR/resources_details.yaml"
else
  kubectl get all -n "$NS" -o yaml > "$DIR/resources_details_all.yaml"
  grep -E "^(kind:|metadata:|  name: ($FILTER_REGEX))" "$DIR/resources_details_all.yaml" > "$DIR/resources_details.yaml" || cp "$DIR/resources_details_all.yaml" "$DIR/resources_details.yaml"
  rm "$DIR/resources_details_all.yaml"
fi

echo "Pulling kubernetes events..."
kubectl get events -n "$NS" --sort-by=.lastTimestamp > "$DIR/events.txt"

echo "Pulling resource usage for filtered pods..."
if [ -n "$FILTER_LABELS" ]; then
  kubectl top pods -n "$NS" -l "$FILTER_LABELS" --containers > "$DIR/pod-resource-usage.txt"
else
  kubectl top pods -n "$NS" --containers | grep -E "^(NAME|$FILTER_REGEX)" > "$DIR/pod-resource-usage.txt"
fi

echo "Pulling container logs for filtered pods only. Also pulling previous logs from restarted containers..."
mkdir -p "$DIR/logs"

# Get filtered pods
if [ -n "$FILTER_LABELS" ]; then
  PODS=$(kubectl get pods -n "$NS" -l "$FILTER_LABELS" -o jsonpath='{.items[*].metadata.name}')
else
  PODS=$(kubectl get pods -n "$NS" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -E "^$FILTER_REGEX" | tr '\n' ' ')
fi

for POD in $PODS; do
  CONTAINERS=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[*].name}')
  for CONTAINER in $CONTAINERS; do
    echo "Pulling current container logs (last 24h) for $POD/$CONTAINER..."
    kubectl logs -n "$NS" "$POD" -c "$CONTAINER" --since=24h > "$DIR/logs/${POD}_${CONTAINER}_current.log" 2>/dev/null

    RESTART_COUNT=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.containerStatuses[?(@.name=="'$CONTAINER'")].restartCount}')
    if [ "$RESTART_COUNT" -gt 0 ]; then
      echo "Pulling previous container logs for $POD/$CONTAINER..."
      kubectl logs -n "$NS" "$POD" -c "$CONTAINER" --previous > "$DIR/logs/${POD}_${CONTAINER}_previous.log" 2>/dev/null
    fi
  done
done

echo "Compressing debugging info..."
tar -czf "$DIR.tar.gz" -C /tmp "$(basename "$DIR")"

echo "Debugging info saved to $DIR.tar.gz"
echo "Directory contents:"
ls -la "$DIR"
