use strict;
use warnings;
use GCCJIT::Context;
use GCCJIT qw/:all/;
use Ouroboros qw/:all/;

my $ctx = GCCJIT::Context->acquire();

my $int_type = $ctx->get_type(GCC_JIT_TYPE_INT);
my $void_type = $ctx->get_type(GCC_JIT_TYPE_VOID);
my $void_ptr_type = $ctx->get_type(GCC_JIT_TYPE_VOID_PTR);

my $stack_type = $ctx->new_struct_type(undef, "ouroboros_stack", [
    $ctx->new_field(undef, $void_ptr_type, "sp"),
    $ctx->new_field(undef, $void_ptr_type, "mark"),
    $ctx->new_field(undef, $int_type, "ax"),
    $ctx->new_field(undef, $int_type, "items"),
])->as_type();

my $stack_op_type = $ctx->new_function_ptr_type(undef,
    $void_type, [ $void_ptr_type, $void_ptr_type ], 0);

my $stack_op_int_type = $ctx->new_function_ptr_type(undef,
    $void_ptr_type, [ $void_ptr_type, $void_ptr_type, $int_type ], 0);

my $sv_iv_type = $ctx->new_function_ptr_type(undef, 
    $int_type, [ $void_ptr_type, $void_ptr_type ], 0);

my $stack_init_ptr = $ctx->new_rvalue_from_ptr(
    $stack_op_type, 
    ouroboros_stack_init_ptr);
my $stack_prepush_ptr = $ctx->new_rvalue_from_ptr(
    $stack_op_type,
    ouroboros_stack_prepush_ptr);
my $stack_putback_ptr = $ctx->new_rvalue_from_ptr(
    $stack_op_type, 
    ouroboros_stack_putback_ptr);
my $stack_fetch_ptr = $ctx->new_rvalue_from_ptr(
    $stack_op_int_type, 
    ouroboros_stack_fetch_ptr);
my $stack_xpush_iv_ptr = $ctx->new_rvalue_from_ptr(
    $stack_op_int_type,
    ouroboros_stack_xpush_iv_ptr);
my $sv_iv_ptr = $ctx->new_rvalue_from_ptr(
    $sv_iv_type,
    ouroboros_sv_iv_ptr);

my $perl = $ctx->new_param(undef, $void_ptr_type, "perl");
my $cv = $ctx->new_param(undef, $void_ptr_type, "cv");

my $fn = $ctx->new_function(undef, GCC_JIT_FUNCTION_EXPORTED,
    $void_type, "square", [ $perl, $cv ],
    0);

my $stack = $fn->new_local(undef, $stack_type, "stack");
my $stack_ptr = $stack->get_address(undef);

my $perl_ptr = $perl->as_rvalue();
my $block = $fn->new_block("my block");

$block->add_eval(undef, $ctx->new_call_through_ptr(undef,
    $stack_init_ptr, [ $perl_ptr, $stack_ptr ]));

my $param_sv = $ctx->new_call_through_ptr(undef,
    $stack_fetch_ptr, [ $perl_ptr, $stack_ptr, $ctx->zero($int_type) ]);

my $param_int = $ctx->new_call_through_ptr(undef,
    $sv_iv_ptr, [ $perl_ptr, $param_sv ]);

my $rvalue = $ctx->new_binary_op(undef,
    GCC_JIT_BINARY_OP_MULT,
    $int_type, $param_int, $param_int);

$block->add_eval(undef, $ctx->new_call_through_ptr(undef,
    $stack_prepush_ptr, [ $perl_ptr, $stack_ptr ]));

$block->add_eval(undef, $ctx->new_call_through_ptr(undef,
    $stack_xpush_iv_ptr, [ $perl_ptr, $stack_ptr, $rvalue ]));

$block->add_eval(undef, $ctx->new_call_through_ptr(undef,
    $stack_putback_ptr, [ $perl_ptr, $stack_ptr ]));

$block->end_with_void_return(undef);

our $result = $ctx->compile;
my $ptr = $result->get_code("square");

use DynaLoader;
use feature "say";

my $xs = DynaLoader::dl_install_xsub("main::square", $ptr);

say square(4);

{ no warnings; push @{$main::stash}, $result; $xs }
