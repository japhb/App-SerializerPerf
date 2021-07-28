unit module App::SerializerPerf:auth<zef:japhb>:api<0>:ver<0.0.1>;

# NOTE: To test a structure pulled from a JSON file, you'll need a JSON test
#       file to work with.  I snapshotted mine from ~/.zef/store/360.zef.pm .


# Bidirectional codecs
use YAMLish;
use JSON::Fast;
use CBOR::Simple;
use BSON::Simple;
use BSON::Document;

# Parse-only decoders
use JSON::Hjson;


# my @order  = < JSON::Fast CBOR::Simple BSON::Simple BSON::Document JSON::Hjson YAMLish .raku/EVAL >;
my @order  = < JSON::Fast CBOR::Simple BSON::Simple >;
my $length = @order.map(*.chars).max;


sub time-them(%by-codec) {
    my $count = $*COUNT;
    my $runs  = $*RUNS;
    my %times;

    for ^$runs {
        for @order -> $codec {
            next unless my $test-code := %by-codec{$codec};

            CATCH { default { } }

            my $ts = now;
            $test-code() for ^$count;
            my $te = now;

            %times{$codec}.append($te - $ts);
        }
    }

    %times
}

sub show-times(Str:D $test, %times) {
    say "\n$test:";
    my $reference;
    for @order -> $codec {
        next unless %times{$codec} && my $fastest = %times{$codec}.min;
        if $reference {
            printf "%-{$length}s  %8.3fs (%.3fx)\n",
                   $codec, $fastest, $fastest / $reference;
        }
        else {
            printf "%-{$length}s  %8.3fs\n", $codec, $fastest;
            $reference = $fastest;
        }
    }
}

sub time-and-show(Str:D $test, %by-codec) {
    show-times($test, time-them(%by-codec));
}

sub show-sizes(%blobs) {
    say "\nSizes:";
    my $reference;
    for @order -> $codec {
        unless my $blob = %blobs{$codec} {
            printf "%-{$length}s  %8s\n", $codec, 'NONE';
            next;
        }

        my $size = $blob.bytes;

        if $reference {
            printf "%-{$length}s  %8d (%.3fx)\n",
                   $codec, $size, $size / $reference;
        }
        else {
            printf "%-{$length}s  %8d\n", $codec, $size;
            $reference = $size;
        }
    }
}

sub show-reliability(%encoders, %decoders) {
    say "\nReliability:";
    for @order -> $codec {
        my @errors;
        if %encoders{$codec} -> $encoder {
            $encoder();
            CATCH { default { @errors.push: "Encoder failure for $codec:\n{.Str.indent(4)}" } }
        }

        if %decoders{$codec} -> $decoder {
            $decoder();
            CATCH { default { @errors.push: "Decoder failure for $codec:\n{.Str.indent(4)}" } }
        }

        printf "%-{$length}s  %8s\n", $codec, @errors ?? 'FAIL' !! 'pass';
        .indent(4).say for @errors;
    }
}

sub show-fidelity(%by-codec, $reference) {
    say "\nFidelity:";

    for @order -> $codec {
        next unless my $decoder = %by-codec{$codec};
        my $decoded = try $decoder();

        printf "%-{$length}s  %8s\n",
               $codec, $decoded eqv $reference ?? 'pass' !! 'FAIL';
    }
}


sub time-codecs(Str:D $variant, $struct) is export {
    say "\n====> $variant <====";

    use MONKEY-SEE-NO-EVAL;
    my $*BSON_SIMPLE_PLAIN_HASHES = True;
    my $*BSON_SIMPLE_PLAIN_BLOBS  = True;

    my $yaml = try save-yaml($struct).encode;
    my $raku = try $struct.raku.encode;
    my $json = try to-json($struct, :!pretty).encode;
    my $bson = try bson-encode { b => $struct };
    my $cbor = try cbor-encode $struct;

    my $doc  = try BSON::Document.new($bson);
    my $doce = try $doc.encode;

    my %blobs := {
        'JSON::Fast'     => $json,
        'CBOR::Simple'   => $cbor,
        'BSON::Simple'   => $bson,
        'BSON::Document' => $doce,
        '.raku/EVAL'     => $raku,
        'YAMLish'        => $yaml,
    };

    my %encoders := {
        'JSON::Fast'     => { my $j = to-json($struct, :!pretty).encode },
        'CBOR::Simple'   => { my $c = cbor-encode $struct },
        'BSON::Simple'   => { my $b = bson-encode { b => $struct } },
        'BSON::Document' => { my $d = $doc.encode },
        '.raku/EVAL'     => { my $r = $struct.raku.encode },
        'YAMLish'        => { my $y = save-yaml($struct).encode },
    };

    my %decoders := {
        'JSON::Fast'     => { my $j = from-json  $json.decode },
        'JSON::Hjson'    => { my $h = from-hjson $json.decode },
        'CBOR::Simple'   => { my $c = cbor-decode $cbor },
        'BSON::Simple'   => { my $b = bson-decode($bson)<b> },
        'BSON::Document' => { my $d = BSON::Document.new($doce)<b> },
        '.raku/EVAL'     => { my $r = EVAL $raku.decode },
        'YAMLish'        => { my $y = load-yaml $yaml.decode },
    };

    show-sizes(%blobs);
    show-reliability(%encoders, %decoders);
    show-fidelity(%decoders, $struct);
    time-and-show('Encode', %encoders);
    time-and-show('Decode', %decoders);
}


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
 JSON::Hjson    | JSON   | *     | Poor  | Fair     | Good*
 YAMLish        | YAML   | Poor  | Poor  | Fair     | BEST
 .raku/EVAL     | Raku   | Poor  | Poor  | BEST     | Fair

(Note: C<JSON::Hjson> is a decoder I<only>, and has no native encode ability.
Thus performance and fidelity was tested against inputs in the JSON subset of
Hjson, though of course the point of Hjson is to allow more human-friendly
variation in data formatting -- similar to YAML in that respect.)

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
