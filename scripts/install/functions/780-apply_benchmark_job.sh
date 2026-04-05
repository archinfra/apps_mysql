apply_benchmark_job() {
  render_manifest "${BENCHMARK_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}

