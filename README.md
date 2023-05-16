# Templar

C++ HTML template compiler

This is a perl script that compiles a directory of `.tmpl` files into a C++17 header file. This header file can then be used in a C++ application to emit HTML.

Inspired by [hypertextcpp](https://github.com/kamchatka-volcano/hypertextcpp) with a few differences:

* Automatic HTML escaping to protect against XSS bugs
  * The normal `$(...)` replacement will perform escaping, ie convert `<` into `&lt;` etc
  * If the replacement is inside an HTML attribute, single/double quotes are also escaped
  * If you want to *not* do the escaping, use the form `$!(...)`
    * Since they return HTML, this is what you should use when calling other templates. For example, here's how use the template in `items/myItem.tmpl` as a sub-template: `$!(items::myItem(ctx.item))`
* Minification: Non-semantic whitespace in the template HTML is (mostly) removed at compile-time
* Single header output, as opposed to header per template
  * Converts directory structure of templates into namespaces
  * All templates are forward-declared so any template can call into another sub-template
* Instead of iostreams, this module concatenates strings
  * Rather than outputing independent C++ statements for each tag, templar coalesces adjacent literals into a single statement
  * I don't know if the above changes improve or degrade performance. There are arguments both ways, and I have not benchmarked anything
* Single-stage build process (no need to compile the template compiler)
* Output headers start with `#pragma once`
* Parameter struct is named `ctx` not `cfg`
* Less tested, missing some features
  * Currently unimplemented: sections, procedures, shared library renderer
  * A bit more limited in what types `$()` and co can return. It has to be a string/string_view, or have an `std::to_string()` overload

## Dependencies

Template depends on `Regexp::Grammars` and `Template` perl modules. On debian/ubuntu systems you can install these packages:

    sudo apt install -y libregexp-grammars-perl libtemplate-perl

## Usage

See the setup in the `ex` directory. To compile:

    ./templar.pl tmpls/ tmpl mytmpls.h

* `tmpls/` is a directory that contains `.tmpl` files (all sub-directories are also searched)
* `tmpl` is the C++ namespace for your templates
* `mytmpls.h` is the output header file

## Copyright

(C) 2023 Doug Hoyte

MIT license
