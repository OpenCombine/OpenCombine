${{template_header}}
%{{
from gyb_opencombine_support import (
    if_canimport_combine,
    endif_canimport_combine,
    benchmark_preamble,
    frameworks_under_test
)

benchmark_name = '{name}'
}}%
${{benchmark_preamble(benchmark_name)}}
let factor = 10000
% for framework_under_test in frameworks_under_test:
${{if_canimport_combine(framework_under_test)}}
@inline(never)
public func run_${{benchmark_name}}_${{framework_under_test}}(N: Int) {{
    for i in 1...(factor * N) {{
        // TODO
    }}
}}
${{endif_canimport_combine(framework_under_test)}}
% end
