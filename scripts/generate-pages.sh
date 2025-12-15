#!/bin/bash
# scripts/generate-pages.sh
# Generates individual HTML pages for each template
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PAGE_DIR="${REPO_ROOT}/page"
TEMPLATES_DIR="${REPO_ROOT}/templates"
TEMPLATE_HTML="${PAGE_DIR}/_template.html"
OUTPUT_DIR="${PAGE_DIR}/templates"

# GitHub repository (set via env or default)
GITHUB_REPO="${GITHUB_REPOSITORY:-Deroy2112/proxmox-lxc-templates}"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Check dependencies
command -v yq >/dev/null 2>&1 || { echo "Error: yq is required"; exit 1; }

# Process each template
for template_dir in "${TEMPLATES_DIR}"/*/; do
  [[ -d "$template_dir" ]] || continue

  template=$(basename "$template_dir")
  config="${template_dir}config.yml"
  changelog="${template_dir}CHANGELOG.md"

  # Skip if no config
  [[ -f "$config" ]] || continue

  echo "Generating page for: $template"

  # Read config values
  NAME=$(yq -r '.name' "$config")
  DESCRIPTION=$(yq -r '.description // ""' "$config")
  CATEGORY=$(yq -r '.category // ""' "$config")
  VERSION=$(yq -r '.version' "$config")
  BUILD_VERSION=$(yq -r '.build_version' "$config")
  BASE_OS=$(yq -r '.base_os' "$config")
  ARCH=$(yq -r '.architecture // "amd64"' "$config")
  ICON=$(yq -r '.icon // .name' "$config")

  # Resources
  MEM_MIN=$(yq -r '.resources.memory_min // 256' "$config")
  MEM_REC=$(yq -r '.resources.memory_recommended // 512' "$config")
  DISK_MIN=$(yq -r '.resources.disk_min // "2G"' "$config")
  DISK_REC=$(yq -r '.resources.disk_recommended // "5G"' "$config")
  CORES=$(yq -r '.resources.cores // 1' "$config")

  # Quick start
  QUICK_START=$(yq -r '.quick_start // ""' "$config")

  # Credentials
  CRED_USER=$(yq -r '.credentials.username // ""' "$config")
  CRED_PASS=$(yq -r '.credentials.password // ""' "$config")
  CRED_NOTE=$(yq -r '.credentials.note // ""' "$config")

  # Computed values
  FULL_VERSION="${VERSION}-${BUILD_VERSION}"
  TAG="v${FULL_VERSION}-${NAME}"
  FILENAME="deroy2112-${BASE_OS}-${NAME}_${FULL_VERSION}_${ARCH}.tar.zst"
  URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${FILENAME}"
  CHANGELOG_URL="https://github.com/${GITHUB_REPO}/blob/main/templates/${template}/CHANGELOG.md"
  RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/tag/${TAG}"

  # Get SHA512 from release (if available)
  SHA512=""
  if command -v gh >/dev/null 2>&1; then
    SHA512=$(gh release download "$TAG" --pattern "${FILENAME}.sha512" -O - 2>/dev/null | cut -d' ' -f1 || echo "")
  fi
  [[ -z "$SHA512" ]] && SHA512="(available after release)"

  # Generate ports table rows
  PORTS_ROWS=""
  port_count=$(yq -r '.ports | length' "$config")
  for ((i=0; i<port_count; i++)); do
    port=$(yq -r ".ports[$i].port" "$config")
    desc=$(yq -r ".ports[$i].description // \"\"" "$config")
    PORTS_ROWS+="<tr><td><code>${port}</code></td><td>${desc}</td></tr>"
  done
  [[ -z "$PORTS_ROWS" ]] && PORTS_ROWS="<tr><td colspan=\"2\" class=\"text-muted\">No ports defined</td></tr>"

  # Generate paths table rows
  PATHS_ROWS=""
  path_count=$(yq -r '.paths | length' "$config")
  for ((i=0; i<path_count; i++)); do
    path=$(yq -r ".paths[$i].path" "$config")
    desc=$(yq -r ".paths[$i].description // \"\"" "$config")
    PATHS_ROWS+="<tr><td><code>${path}</code></td><td>${desc}</td></tr>"
  done
  [[ -z "$PATHS_ROWS" ]] && PATHS_ROWS="<tr><td colspan=\"2\" class=\"text-muted\">No paths defined</td></tr>"

  # Generate FAQ items
  FAQ_ITEMS=""
  faq_count=$(yq -r '.faq | length' "$config")
  if [[ "$faq_count" -gt 0 ]]; then
    for ((i=0; i<faq_count; i++)); do
      question=$(yq -r ".faq[$i].question" "$config")
      answer=$(yq -r ".faq[$i].answer" "$config")
      # Escape HTML in answer
      answer=$(echo "$answer" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/`/<code>/g; s/`/<\/code>/g')
      FAQ_ITEMS+="<div class=\"faq-item\">"
      FAQ_ITEMS+="<button class=\"faq-question\">${question}"
      FAQ_ITEMS+="<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"6 9 12 15 18 9\"></polyline></svg>"
      FAQ_ITEMS+="</button>"
      FAQ_ITEMS+="<div class=\"faq-answer\"><p>${answer}</p></div>"
      FAQ_ITEMS+="</div>"
    done
  fi

  # Read changelog (first 50 lines or so)
  CHANGELOG=""
  if [[ -f "$changelog" ]]; then
    # Convert markdown to basic HTML
    CHANGELOG=$(head -100 "$changelog" | sed '
      s/^## \[\([^]]*\)\]/\n<h3>[\1]<\/h3>/g
      s/^### \(.*\)/<h4>\1<\/h4>/g
      s/^- \(.*\)/<li>\1<\/li>/g
      s/`\([^`]*\)`/<code>\1<\/code>/g
    ')
  else
    CHANGELOG="<p class=\"text-muted\">No changelog available.</p>"
  fi

  # Read template and substitute
  output="${OUTPUT_DIR}/${NAME}.html"

  sed -e "s|{{NAME}}|${NAME}|g" \
      -e "s|{{DESCRIPTION}}|${DESCRIPTION}|g" \
      -e "s|{{CATEGORY}}|${CATEGORY}|g" \
      -e "s|{{VERSION}}|${FULL_VERSION}|g" \
      -e "s|{{OS}}|${BASE_OS}|g" \
      -e "s|{{ARCH}}|${ARCH}|g" \
      -e "s|{{ICON}}|${ICON}|g" \
      -e "s|{{FILENAME}}|${FILENAME}|g" \
      -e "s|{{URL}}|${URL}|g" \
      -e "s|{{SHA512}}|${SHA512}|g" \
      -e "s|{{RELEASE_URL}}|${RELEASE_URL}|g" \
      -e "s|{{CHANGELOG_URL}}|${CHANGELOG_URL}|g" \
      -e "s|{{MEM_MIN}}|${MEM_MIN}|g" \
      -e "s|{{MEM_REC}}|${MEM_REC}|g" \
      -e "s|{{DISK_MIN}}|${DISK_MIN}|g" \
      -e "s|{{DISK_REC}}|${DISK_REC}|g" \
      -e "s|{{CORES}}|${CORES}|g" \
      -e "s|{{PORTS_ROWS}}|${PORTS_ROWS}|g" \
      -e "s|{{PATHS_ROWS}}|${PATHS_ROWS}|g" \
      -e "s|{{CRED_USER}}|${CRED_USER}|g" \
      -e "s|{{CRED_PASS}}|${CRED_PASS}|g" \
      -e "s|{{CRED_NOTE}}|${CRED_NOTE}|g" \
      "$TEMPLATE_HTML" > "$output"

  # Handle conditional sections and multi-line replacements with awk
  awk -v quick_start="$QUICK_START" \
      -v faq_items="$FAQ_ITEMS" \
      -v changelog="$CHANGELOG" \
      -v has_creds="$([[ -n "$CRED_USER" ]] && echo "1" || echo "")" \
      -v has_faq="$([[ "$faq_count" -gt 0 ]] && echo "1" || echo "")" \
      -v cred_note="$CRED_NOTE" '
  {
    # Quick start
    if (/\{\{#QUICK_START\}\}/) { in_quick=1; if (quick_start != "") print; next }
    if (/\{\{\/QUICK_START\}\}/) { in_quick=0; if (quick_start != "") print; next }
    if (in_quick && quick_start == "") next

    # Credentials
    if (/\{\{#CREDENTIALS\}\}/) { in_creds=1; if (has_creds) print; next }
    if (/\{\{\/CREDENTIALS\}\}/) { in_creds=0; if (has_creds) print; next }
    if (in_creds && !has_creds) next

    # Credential note
    if (/\{\{#CRED_NOTE\}\}/) { in_cred_note=1; if (cred_note != "") print; next }
    if (/\{\{\/CRED_NOTE\}\}/) { in_cred_note=0; if (cred_note != "") print; next }
    if (in_cred_note && cred_note == "") next

    # FAQ
    if (/\{\{#FAQ\}\}/) { in_faq=1; if (has_faq) print; next }
    if (/\{\{\/FAQ\}\}/) { in_faq=0; if (has_faq) print; next }
    if (in_faq && !has_faq) next

    # Replace placeholders
    gsub(/\{\{QUICK_START\}\}/, quick_start)
    gsub(/\{\{FAQ_ITEMS\}\}/, faq_items)
    gsub(/\{\{CHANGELOG\}\}/, changelog)

    print
  }' "$output" > "${output}.tmp" && mv "${output}.tmp" "$output"

  echo "  -> ${output}"
done

echo "Page generation complete!"
