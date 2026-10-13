# shellcheck shell=bash
# chart_images.sh
# Read the image list from the chart these scripts ship in. Sourced by mirror_langsmith_images.sh
# and create_marketplace_version.sh, which set CHART_DIR before sourcing it.

# Print a top-level field of Chart.yaml, such as appVersion.
chart_field() {
    sed -n "s/^$1: *[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\} *\$/\1/p" "$CHART_DIR/Chart.yaml"
}

# Print "<key> <repository> <tag>" for each entry under images: that has a repository.
# An empty tag prints as "-". Fails if an *Image entry has no repository this parser can read.
list_chart_images() {
    awk -v q="'" '
        function unquote(s) { gsub("[\"" q "]", "", s); return s }
        function flush() {
            if (key ~ /Image$/ && repo == "") {
                print "ERROR: could not read images." key ".repository from values.yaml" > "/dev/stderr"
                bad = 1
            } else if (key != "" && repo != "") {
                print key, repo, (tag == "" ? "-" : tag)
            }
            key = ""
        }
        /^images:/ { in_images = 1; next }
        in_images && /^[^ #]/ { flush(); in_images = 0; exit }
        !in_images || /^ *#/ { next }
        /^  [A-Za-z0-9_-]+:/ { flush(); key = $1; sub(/:$/, "", key); repo = ""; tag = ""; next }
        /^    repository:/ { repo = unquote($2) }
        /^    tag:/ { tag = unquote($2) }
        END { if (in_images) flush(); exit bad }
    ' "$CHART_DIR/values.yaml"
}

# Print "operatorTemplate <repository> <tag>" for each literal image in operator.templates, such as
# the Postgres and Redis the operator creates for each deployment.
list_operator_template_images() {
    awk -v q="'" '
        /^operator:/ { in_operator = 1; next }
        in_operator && /^[^ #]/ { exit }
        in_operator && /^  [A-Za-z]/ { in_templates = ($1 == "templates:"); next }
        in_templates && $1 == "image:" && $2 !~ /\$/ {
            image = $2; gsub("[\"" q "]", "", image)
            i = match(image, /:[^:\/]*$/)
            if (i) { repo = substr(image, 1, i - 1); tag = substr(image, i + 1) } else { repo = image; tag = "latest" }
            if (repo !~ /^[^\/]*[.:][^\/]*\//) repo = "docker.io/" repo
            print "operatorTemplate", repo, tag
        }
    ' "$CHART_DIR/values.yaml"
}

# Print "<key> <repository> <tag>" for each image to mirror. Reads APP_VERSION, VERSION,
# OPERATOR_VERSION, INCLUDE_SANDBOXES, and INCLUDE_PRESIDIO.
chart_images() {
    local images key repo tag
    images=$(list_chart_images) || return 1
    images+=$'\n'$(list_operator_template_images)

    while read -r key repo tag; do
        [[ -n $key ]] || continue
        case $key in
            sandboxHostImage|juicefs*) $INCLUDE_SANDBOXES || continue ;;
            presidioAnalyzerImage) $INCLUDE_PRESIDIO || continue ;;
        esac

        # LangSmith images track appVersion; an empty tag means the chart defaults it to appVersion.
        if [[ $key == operatorImage ]]; then
            tag="${OPERATOR_VERSION:-$tag}"
        elif [[ $tag == "-" || $tag == "$APP_VERSION" ]]; then
            tag="$VERSION"
        fi

        echo "${key} ${repo} ${tag}"
    done <<<"$images"
}
