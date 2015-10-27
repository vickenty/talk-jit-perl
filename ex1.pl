use strict;
use warnings;
use GCCJIT::Context;
use GCCJIT qw/:all/;

my $ctx = GCCJIT::Context->acquire();

my $int_type = $ctx->get_type(GCC_JIT_TYPE_INT);

my $param = $ctx->new_param(undef, $int_type, "param");
my $fn = $ctx->new_function(undef, GCC_JIT_FUNCTION_EXPORTED,
    $int_type, "square", [ $param ],
    0,
);

my $rvalue = $ctx->new_binary_op(undef,
    GCC_JIT_BINARY_OP_MULT,
    $int_type,
    $param->as_rvalue(),
    $param->as_rvalue(),
);

my $block = $fn->new_block("my block");
$block->end_with_return(undef, $rvalue);

my $result = $ctx->compile;
my $ptr = $result->get_code("square");

use FFI::Raw;
use feature "say";

my $ffi = FFI::Raw->new_from_ptr(
    $ptr, FFI::Raw::int, FFI::Raw::int
)->coderef;

say $ffi->(4);

{ no warnings; push @{$main::stash}, $result; $ffi }
