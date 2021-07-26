unit module App::SerializerPerf:auth<zef:japhb>:api<0>:ver<0.0.1>;


=begin pod

=head1 NAME

serializer-perf - Performance tests for data serializer codecs

=head1 SYNOPSIS

=begin code :lang<shell>

serializer-perf [--runs=UInt] [--count=UInt] [--source=Path]

 --runs=<UInt>    Runs per test (for stable results)
 --count=<UInt>   Encodes/decodes per run (for sufficient duration)
 --source=<Path>  Test file containing JSON data

=end code

=head1 DESCRIPTION

C<serializer-perf> is a test suite of performance and correctness (fidelity)
tests for data serializer codecs.  It is currently able to test the following
codecs:

=table
 Codec          | Format | Size  | Speed | Fidelity | Human-Friendly
 ===================================================================
 BSON::Document | BSON   | Mixed | Poor  | Poor     | Poor
 BSON::Simple   | BSON   | Mixed | Fair  | Fair     | Poor
 CBOR::Simple   | CBOR   | BEST  | BEST  | Good     | Poor
 JSON::Fast     | JSON   | Fair  | Good  | Fair     | Good
 YAMLish        | YAML   | Poor  | Poor  | Fair     | BEST
 .raku/EVAL     | Raku   | Poor  | Poor  | BEST     | Fair

Because some of the tests are I<very> slow, the default values for C<--runs>
and C<--count> are 1 and 10 respectively.  If only testing the faster codecs
(those with Speed of Fair or better in the table above), these will be too low;
5 and 100 are more appropriate values in that case.


=head1 AUTHOR

Geoffrey Broadwell <gjb@sonic.net>


=head1 COPYRIGHT AND LICENSE

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.

=end pod
