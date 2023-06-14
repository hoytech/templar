#!/usr/bin/env perl

use strict;

use Template;
use File::Find;
use Data::Dumper;

use FindBin qw($RealBin);
use lib $RealBin;
use Parser;


my $tmplDir = shift // usage();
my $namespace = shift // usage();
my $outputFile = shift // usage();

sub usage {
    die "usage: $0 <template-directory> <cpp namespace> <output-file>\n";
}


my $dataTmpl; { undef $/; $dataTmpl = <DATA>; }
my $tt = Template->new({});



my $ctx = {
    cppNamespace => $namespace,
    files => [],
};

$tmplDir =~ s{/*$}{};

my @allFilenames;
find({ wanted => sub { push @allFilenames, $_ if /[.]tmpl$/ }, no_chdir => 1, }, $tmplDir);

for my $filename (sort @allFilenames) {
    $filename =~ m{$tmplDir/?(.*)/([^/]+)\.tmpl$};
    my $path = $1;
    my $filenameClean = $2;

    $filenameClean =~ s/-/_/g;
    $path = [ split m{/+}, $path ];
    my $pathNice = $namespace;
    $pathNice .= "::$_" foreach @$path;

    push @{ $ctx->{files} }, {
        path => $path,
        pathNice => $pathNice,
        filename => $filenameClean,
        contents => renderCpp($filenameClean, slurp_file($filename)),
    };
}

my $outputStr = '';
$tt->process(\$dataTmpl, $ctx, \$outputStr)
    || die $tt->error(), "\n";

unslurp_file($outputStr, $outputFile);





sub emitLiteral {
    my ($l, $o) = @_;
    push @$o, { literal => $l, };
}

sub emitLiteralWithReplace {
    my ($l, $o, $isAttr) = @_;

    if ($l =~ $Parser::replacementParser) {
        my $parsed = \%/;
        for my $frag (@{ $parsed->{fragment} }) {
            my $isRaw = $frag->{noescape};
            push @$o, { literal => $frag->{before}, isAttr => !!$isAttr, };
            push @$o, { replacement => $frag->{replacement}, isRaw => !!$isRaw, isAttr => !!$isAttr, } if defined $frag->{replacement};
        }
    } else {
        die "Parse error in replacement: " . Dumper(\@!);
    }
}

sub emitTag {
    my ($tagName, $attrs, $o) = @_;
    $attrs = ($attrs || {})->{attr} || [];

    emitLiteral("<$tagName", $o);

    for my $attr (@$attrs) {
        if ($attr->{delim}) {
            emitLiteral(" $attr->{name}=$attr->{delim}", $o);
            emitLiteralWithReplace($attr->{val}, $o, 1);
            emitLiteral("$attr->{delim}", $o);
        } else {
            emitLiteral(" $attr->{name}", $o);
        }
    }

    emitLiteral(">", $o);
}

sub recurseCpp {
    my ($p, $o) = @_;

    return if !ref $p;

    emitLiteralWithReplace($p->{before}->{''}, $o) if defined $p->{before};

    die "can't have both pre and post tag modifiers" if $p->{tagModifierPre} && $p->{tagModifierPost};

    my $tagModifier = $p->{tagModifierPre} // $p->{tagModifierPost};

    if ($tagModifier) {
        emitLiteral($tagModifier->{before}, $o) if defined $tagModifier->{before};

        if ($tagModifier->{mod} eq '@') {
            push @$o, { raw => qq[for $tagModifier->{parenGroup} {], }; #}
        } elsif ($tagModifier->{mod} eq '?') {
            push @$o, { raw => qq[if $tagModifier->{parenGroup} {], }; #}
        } else {
            die "unknown tagModifier";
        }
    }

    if (defined $p->{verbatimTag}) {
        emitLiteralWithReplace($p->{verbatimTag}, $o, 1);
    } elsif (defined $p->{oTagName}) {
        emitTag($p->{oTagName}, $p->{attrList}, $o);
    } elsif (defined $p->{vTagName}) {
        emitTag($p->{vTagName}, $p->{attrList}, $o);
    }

    emitLiteralWithReplace($p->{beforeInner}->{''}, $o) if defined $p->{beforeInner} && $p->{beforeInner} ne '';

    for (my $i = 0; $i < @{ $p->{tag} || [] }; $i++) {
        recurseCpp($p->{tag}->[$i], $o);
        emitLiteralWithReplace($p->{sep}->[$i]->{''}, $o);
    }

    emitLiteral("</$p->{oTagName}>", $o) if defined $p->{oTagName};

    if ($tagModifier) { #{
        push @$o, { raw => qq[}], };
    }
}

sub renderCpp {
    my ($filename, $inp) = @_;

    my $o = [];

    if ($inp =~ $Parser::htmlParser) {
        my $parsed = \%/;
        #print Dumper($parsed);
        recurseCpp($parsed, $o);
    } else {
        die "Parse error: " . Dumper(\@!);
    }


    ## Pass 1: merge adjacent literals of same attribute class (attr vs non-attr)

    {
        my $o2 = [];

        for my $item (@$o) {
            if (defined $item->{literal} && @$o2 && defined $o2->[-1]->{literal} && $item->{isAttr} == $o2->[-1]->{isAttr}) {
                $o2->[-1]->{literal} .= $item->{literal};
            } else {
                push @$o2, $item;
            }
        }

        $o = $o2;
    }


    ## Pass 2: Collapse whitespace, do C++ string escaping

    for my $item (@$o) {
        if (defined $item->{literal}) {
            my $l = $item->{literal};

            $l =~ s/\s+/ /g if !$item->{isAttr}; # minify whitespace, except in attributes

            $l =~ s/"/\\"/g;
            $l =~ s/\n/\\n/g;

            $item->{literal} = $l;
        }
    }


    ## Pass 3: Merge all adjacent literals (ignore attribute class)

    {
        my $o2 = [];

        for my $item (@$o) {
            if (defined $item->{literal} && @$o2 && defined $o2->[-1]->{literal}) {
                $o2->[-1]->{literal} .= $item->{literal};
            } else {
                push @$o2, $item;
            }
        }

        $o = $o2;
    }


    my $renderStr = '';
    for my $item (@$o) {
        if (defined $item->{literal}) {
            $renderStr .= qq{    ::templarInternal::appendRaw(out, "$item->{literal}");\n} if length($item->{literal});
        } elsif (defined $item->{replacement}) {
            if ($item->{isRaw}) {
                $renderStr .= qq{    ::templarInternal::appendRaw(out, $item->{replacement});\n};
            } else {
                my $isAttr = $item->{isAttr} ? 'true' : 'false';
                $renderStr .= qq{    ::templarInternal::appendEscape(out, $item->{replacement}, $isAttr);\n};
            }
        } elsif (defined $item->{raw}) {
            $renderStr .= qq{$item->{raw}\n};
        }
    }

    return $renderStr;
}


sub slurp_file {
    my $filename = shift // die "need filename";

    open(my $fh, '<', $filename) || die "couldn't open '$filename' for reading: $!";

    local $/;
    return <$fh>;
}

sub unslurp_file {
    my $contents = shift;
    my $filename = shift;

    open(my $fh, '>', $filename) || die "couldn't open '$filename' for writing: $!";

    print $fh $contents;
}



__DATA__
#pragma once

#include <string>
#include <string_view>

struct TemplarResult {
    std::string str;
};

namespace templarInternal {
    inline std::string htmlEscape(std::string_view data, bool escapeQuotes) {
        std::string buffer;
        buffer.reserve(data.size() * 11 / 10);

        if (escapeQuotes) {
            for (size_t i = 0; i < data.size(); i++) {
                switch(data[i]) {
                    case '&':  buffer.append("&amp;");       break;
                    case '\"': buffer.append("&quot;");      break;
                    case '\'': buffer.append("&apos;");      break;
                    case '<':  buffer.append("&lt;");        break;
                    case '>':  buffer.append("&gt;");        break;
                    default:   buffer.append(&data[i], 1);   break;
                }
            }
        } else {
            for (size_t i = 0; i < data.size(); i++) {
                switch(data[i]) {
                    case '&':  buffer.append("&amp;");       break;
                    case '<':  buffer.append("&lt;");        break;
                    case '>':  buffer.append("&gt;");        break;
                    default:   buffer.append(&data[i], 1);   break;
                }
            }
        }

        return buffer;
    }

    // Regular appends (with escaping)

    inline void appendEscape(std::string &out, std::string_view val, bool escapeQuotes) { out += htmlEscape(val, escapeQuotes); }
    inline void appendEscape(std::string &out, const std::string &val, bool escapeQuotes) { out += htmlEscape(val, escapeQuotes); }
    inline void appendEscape(std::string &out, const char *val, bool escapeQuotes) { out += htmlEscape(val, escapeQuotes); }
    inline void appendEscape(std::string &out, const TemplarResult &val, bool escapeQuotes) { out += val.str; }
    template<typename TVal>
    inline void appendEscape(std::string &out, TVal val, bool escapeQuotes) { out += htmlEscape(std::to_string(val), escapeQuotes); }

    // Raw appends (danger: no escaping)

    inline void appendRaw(std::string &out, std::string_view val) { out += val; }
    inline void appendRaw(std::string &out, const std::string &val) { out += val; }
    inline void appendRaw(std::string &out, const char *val) { out += val; }
    template<typename TVal>
    inline void appendRaw(std::string &out, TVal val) { out += std::to_string(val); }
}

namespace [% cppNamespace %] {

//////// Prototypes

[%- FOREACH file IN files %]
// [% file.pathNice %]::[% file.filename %]()
[% FOREACH p IN file.path %]namespace [% p %] { [% END -%]
template<typename TCtx> inline TemplarResult [% file.filename %]([[maybe_unused]]const TCtx &ctx);
[%- END -%]
[% FOREACH p IN file.path %] }[%- END %]

//////// Definitions

[%- FOREACH file IN files %]
// [% file.pathNice %]::[% file.filename %]()
[% FOREACH p IN file.path %]namespace [% p %] { [% END %]
template<typename TCtx> inline TemplarResult [% file.filename %]([[maybe_unused]]const TCtx &ctx) {
    std::string out;

[% file.contents %]
    return TemplarResult{ std::move(out) };
}
[% FOREACH p IN file.path %]}[% END -%]

[% END %]

} // namespace [% cppNamespace %]
