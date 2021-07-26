[![Actions Status](https://github.com/japhb/serializer-perf/workflows/test/badge.svg)](https://github.com/japhb/serializer-perf/actions)

NAME
====

serializer-perf - Performance tests for data serializer codecs

SYNOPSIS
========

```shell
serializer-perf [--runs=UInt] [--count=UInt] [--source=Path]

 --runs=<UInt>    Runs per test (for stable results)
 --count=<UInt>   Encodes/decodes per run (for sufficient duration)
 --source=<Path>  Test file containing JSON data
```

DESCRIPTION
===========

`serializer-perf` is a test suite of performance and correctness (fidelity) tests for data serializer codecs. It is currently able to test the following codecs:

<table class="pod-table">
<thead><tr>
<th>Codec</th> <th>Format</th> <th>Size</th> <th>Speed</th> <th>Fidelity</th> <th>Human-Friendly</th>
</tr></thead>
<tbody>
<tr> <td>BSON::Document</td> <td>BSON</td> <td>Mixed</td> <td>Poor</td> <td>Poor</td> <td>Poor</td> </tr> <tr> <td>BSON::Simple</td> <td>BSON</td> <td>Mixed</td> <td>Fair</td> <td>Fair</td> <td>Poor</td> </tr> <tr> <td>CBOR::Simple</td> <td>CBOR</td> <td>BEST</td> <td>BEST</td> <td>Good</td> <td>Poor</td> </tr> <tr> <td>JSON::Fast</td> <td>JSON</td> <td>Fair</td> <td>Good</td> <td>Fair</td> <td>Good</td> </tr> <tr> <td>YAMLish</td> <td>YAML</td> <td>Poor</td> <td>Poor</td> <td>Fair</td> <td>BEST</td> </tr> <tr> <td>.raku/EVAL</td> <td>Raku</td> <td>Poor</td> <td>Poor</td> <td>BEST</td> <td>Fair</td> </tr>
</tbody>
</table>

Because some of the tests are *very* slow, the default values for `--runs` and `--count` are 1 and 10 respectively. If only testing the faster codecs (those with Speed of Fair or better in the table above), these will be too low; 5 and 100 are more appropriate values in that case.

AUTHOR
======

Geoffrey Broadwell <gjb@sonic.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

