#!/bin/bash

# We expect the namespace hosting all kubernetes resources to be passed as an argument to this script
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --namespace) NS="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

if [ -z "$NS" ]; then
  echo "Usage: $0 --namespace <namespace>"
  exit 1
fi

DIR=/tmp/langchain-debugging-$(date +%Y%m%d%H%M%S)

echo "Starting to pull debugging info. Creating directory $DIR..."
mkdir -p "$DIR"

echo "Pulling summary of resources..."
kubectl get all -n "$NS" -o wide > "$DIR/resources_summary.txt"

echo "Pulling details of all resources..."
kubectl get all -n "$NS" -o yaml > "$DIR/resources_details.yaml"

echo "Pulling kubernetes events..."
kubectl get events -n "$NS" --sort-by=.lastTimestamp > "$DIR/events.txt"

echo "Pulling resource usage for all pods..."
kubectl top pods -n "$NS" --containers > "$DIR/pod-resource-usage.txt"

echo "Pulling container logs for all pods. Also pulling previous logs from restarted containers..."
PODS=$(kubectl get pods -n "$NS" -l app="$NS" -o jsonpath='{.items[*].metadata.name}')

for POD in $PODS; do
  CONTAINERS=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[*].name}')
  for CONTAINER in $CONTAINERS; do
    echo "Pulling current container logs (last 24h)..."
    kubectl logs -n "$NS" "$POD" -c "$CONTAINER" --since=24h > "$DIR/${POD}_${CONTAINER}_current.log" 2>/dev/null

    RESTART_COUNT=$(kubectl get pod "$POD" -n "$NS" -o json | jq ".status.containerStatuses[] | select(.name==\"$CONTAINER\") | .restartCount // 0")
    if [[ "$RESTART_COUNT" -gt 0 ]]; then
      echo "  $POD/$CONTAINER restarted ($RESTART_COUNT times) — grabbing previous logs..."
      kubectl logs -n "$NS" "$POD" -c "$CONTAINER" --previous > "$DIR/${POD}_${CONTAINER}_previous.log" 2>/dev/null
    fi
  done
done

echo "Compressing directory..."
tar -czf "${DIR}.tar.gz" -C "$(dirname "$DIR")" "$(basename "$DIR")"
echo "Bundle written to ${DIR}.tar.gz"
