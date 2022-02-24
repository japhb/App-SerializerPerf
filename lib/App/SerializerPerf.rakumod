unit module App::SerializerPerf:auth<zef:japhb>:api<0>:ver<0.0.2>;

# NOTE: To test a structure pulled from a JSON file, you'll need a JSON test
#       file to work with.  I snapshotted mine from ~/.zef/store/360.zef.pm .


# Parse-only decoders
use JSON::Hjson;

# Bidirectional codecs
use BSON::Document;
use BSON::Simple;
use CBOR::Simple;
use JSON::Fast;
use YAMLish;

# All used the same exported names
use Config::TOML           Empty;
use TOML:auth<zef:tony-o>  Empty;
use TOML::Thumb            Empty;

# Disambiguate codecs that used the same exported names
constant &config-toml-encode = Config::TOML::EXPORT::DEFAULT::<&to-toml>;
constant &config-toml-decode = Config::TOML::EXPORT::DEFAULT::<&from-toml>;
constant &toml-tony-o-encode = TOML::EXPORT::DEFAULT::<&to-toml>;
constant &toml-tony-o-decode = TOML::EXPORT::DEFAULT::<&from-toml>;
constant &toml-thumb-encode  = TOML::Thumb::EXPORT::DEFAULT::<&to-toml>;
constant &toml-thumb-decode  = TOML::Thumb::EXPORT::DEFAULT::<&from-toml>;


my @order  = < JSON::Fast CBOR::Simple BSON::Simple >;
my @toml   = < TOML(tony-o) TOML::Thumb Config::TOML >;
my @slow   = < BSON::Document JSON::Hjson .raku/EVAL YAMLish >;
my $length = (@order, @toml, @slow).flat.map(*.chars).max;
@order.append(@toml);
@order.append(@slow);


sub time-them(%by-codec) {
    my $count = $*COUNT;
    my $runs  = $*RUNS;
    my %times;

    for ^$runs {
        for @order -> $codec {
            next unless my $test-code := %by-codec{$codec};

            CATCH   { default { } }
            CONTROL { when CX::Warn { .resume }
                      default { } }

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
            CATCH   { default { @errors.push: "Encoder failure for $codec:\n{.Str.indent(4)}" } }
            CONTROL { default { @errors.push: "Encoder warning for $codec:\n{.Str.indent(4)}"; .resume } }
        }

        if %decoders{$codec} -> $decoder {
            $decoder();
            CATCH   { default { @errors.push: "Decoder failure for $codec:\n{.Str.indent(4)}" } }
            CONTROL { default { @errors.push: "Decoder warning for $codec:\n{.Str.indent(4)}"; .resume } }
        }

        printf "%-{$length}s  %8s\n", $codec, @errors ?? 'FAIL' !! 'pass';
        .indent(4).say for @errors;
    }
}

sub show-fidelity(%by-codec, $reference) {
    say "\nFidelity:";

    for @order -> $codec {
        next unless my $decoder = %by-codec{$codec};
        my $decoded = try quietly $decoder();

        printf "%-{$length}s  %8s\n",
               $codec, $decoded eqv $reference ?? 'pass' !! 'FAIL';
    }
}


sub time-codecs(Str:D $variant, $struct,
                Bool:D :$size        = True,
                Bool:D :$reliability = True,
                Bool:D :$fidelity    = True,
                Bool:D :$encode      = True,
                Bool:D :$decode      = True,
               ) is export {
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

    my $toml1 = try config-toml-encode({ t => $struct }).encode;
    my $toml2 = try toml-tony-o-encode({ t => $struct }).encode;
    my $toml3 = try toml-thumb-encode( { t => $struct }).encode;

    my %blobs := {
        'JSON::Fast'     => $json,
        'CBOR::Simple'   => $cbor,
        'BSON::Simple'   => $bson,
        'BSON::Document' => $doce,
        'Config::TOML'   => $toml1,
        'TOML(tony-o)'   => $toml2,
        'TOML::Thumb'    => $toml3,
        '.raku/EVAL'     => $raku,
        'YAMLish'        => $yaml,
    };

    my %encoders := {
        'JSON::Fast'     => { my $j = to-json($struct, :!pretty).encode },
        'CBOR::Simple'   => { my $c = cbor-encode $struct },
        'BSON::Simple'   => { my $b = bson-encode { b => $struct } },
        'BSON::Document' => { my $d = $doc.encode },
        'Config::TOML'   => { my $t = config-toml-encode({ t => $struct }).encode },
        'TOML(tony-o)'   => { my $t = toml-tony-o-encode({ t => $struct }).encode },
        'TOML::Thumb'    => { my $t = toml-thumb-encode( { t => $struct }).encode },
        '.raku/EVAL'     => { my $r = $struct.raku.encode },
        'YAMLish'        => { my $y = save-yaml($struct).encode },
    };

    my %decoders := {
        'JSON::Fast'     => { my $j = from-json  $json.decode },
        'JSON::Hjson'    => { my $h = from-hjson $json.decode },
        'CBOR::Simple'   => { my $c = cbor-decode $cbor },
        'BSON::Simple'   => { my $b = bson-decode($bson)<b> },
        'BSON::Document' => { my $d = BSON::Document.new($doce)<b> },
        'Config::TOML'   => { my $t = config-toml-decode($toml1.decode)<t> },
        'TOML(tony-o)'   => { my $t = toml-tony-o-decode($toml2.decode)<t> },
        'TOML::Thumb'    => { my $t = toml-thumb-decode( $toml3.decode)<t> },
        '.raku/EVAL'     => { my $r = EVAL $raku.decode },
        'YAMLish'        => { my $y = load-yaml $yaml.decode },
    };

    show-sizes(%blobs)                     if $size;
    show-reliability(%encoders, %decoders) if $reliability;
    show-fidelity(%decoders, $struct)      if $fidelity;
    time-and-show('Encode', %encoders)     if $encode;
    time-and-show('Decode', %decoders)     if $decode;
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
 TOML::Thumb    | TOML   | Poor  | Mixed | Poor     | Good
 TOML(tony-o)   | TOML   | Poor  | Poor  | Poor     | Good
 Config::TOML   | TOML   | Poor  | Poor  | Poor     | Good
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
