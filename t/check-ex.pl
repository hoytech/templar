#!/usr/bin/env perl

use strict;

my $inp;

{
    undef $/;
    $inp = <STDIN>;
}

## verbatim tag
check(qq{<!DOCTYPE html PUBLIC\n  "-//W3C//DTD XHTML 1.0 Transitional//EN"\n  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">});

## attributes
check(qq{<html lang="en" whatever dir="blah">});

## Calling sub-template
check(qq{<div class="header">});

## Escaping <> but not quotes in regular text
check(qq{Header: MYHEAD &gt; "'123'" &lt; inf </div>});

## Escaping <> and quotes inside attribute
check(qq{<div id='a  bef isn&apos;t it \n &lt;great&gt;? aft'>});

## Void tag
check(qq{<img src="/asdf">});

## Escaping, replacements
check(qq{hello 'doug'! &lt;&gt; num = 123});

## Unescaped replacement
check(qq{<div> <h2>DANGER</h2> </div>});

## Tag modifier
check(qq{<p>NOT HIDDEN</p>});

## Tag modifier, pre
check(qq{<p class="blah"> <div>pre</div> </p>});

## Tag modifier, post
check(qq{<p> <div>post</div> </p>});

## For loop
check(qq{<ul> <li>1.100000</li><li>2.200000</li><li>3.300000</li> </ul>});

## Comment
check(qq{<!-- comment! -->});

## Null tags
check(qq{<div>HI!</div>});
check(qq{I am <b>here</b>});
check(qq{<div> 1234 </div>});

## Wrap up
check(qq{</div> </html>});


$inp =~ s/^\s*//;
die "trailing data: $inp" if $inp ne '';

print "All good.\n";


sub check {
    my $expected = shift;

    $inp =~ s/^\s+//;

    my $got = substr($inp, 0, length($expected));
    die qq{expected '$expected'" but got "$got"} if $expected ne $got;

    $inp = substr($inp, length($expected));
}
