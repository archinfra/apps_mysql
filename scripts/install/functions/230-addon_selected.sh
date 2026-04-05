addon_selected() {
  local addon_name="$1"
  [[ ",${ADDONS}," == *",${addon_name},"* ]]
}

