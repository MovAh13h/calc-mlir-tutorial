"""Test helpers shared across all tutorial stages."""

def mlir_filecheck_test(name, src, mlir_opt = "@llvm-project//mlir:mlir-opt", mlir_opt_args = None):
    """Defines a sh_test that runs `<mlir_opt> [args] src | FileCheck src`.

    Args:
      name: the test target name.
      src: a .mlir file containing both the input IR and `// CHECK*`
        directives describing the expected output of mlir-opt.
      mlir_opt: the mlir-opt-style binary to invoke. Defaults to the
        stock @llvm-project//mlir:mlir-opt. Later stages pass their own
        calc-opt binary so their custom dialect is registered.
      mlir_opt_args: optional list of extra args to pass to mlir-opt
        (e.g. ["--canonicalize"] or ["--pass-pipeline=..."]).
    """
    mlir_opt_args = mlir_opt_args or []
    native.sh_test(
        name = name,
        srcs = ["//common:run_filecheck.sh"],
        args = [
            "$(location {})".format(mlir_opt),
            "$(location @llvm-project//llvm:FileCheck)",
            "$(location {})".format(src),
        ] + mlir_opt_args,
        data = [
            src,
            mlir_opt,
            "@llvm-project//llvm:FileCheck",
        ],
    )

def mlir_verify_diagnostics_test(name, src, mlir_opt):
    """Runs `<mlir_opt> --verify-diagnostics --split-input-file <src>`.

    The .mlir source should contain `// expected-error @+N {{msg}}`,
    `// expected-warning {{msg}}`, etc., directives. MLIR will check
    that every expected diagnostic was emitted and no unexpected ones
    leaked. Test passes iff every expectation matched.

    Used in stages with custom verifiers to test the negative case.

    Args:
      name: the test target name.
      src: a .mlir file with multiple snippets separated by `// -----`,
        each annotated with `// expected-...` directives.
      mlir_opt: the mlir-opt-style binary to invoke (typically the
        stage's calc-opt).
    """
    native.sh_test(
        name = name,
        srcs = ["//common:run_verify_diagnostics.sh"],
        args = [
            "$(location {})".format(mlir_opt),
            "$(location {})".format(src),
        ],
        data = [src, mlir_opt],
    )

def mlir_jit_test(name, src, calc_opt, calc_opt_args = None):
    """Runs `<calc_opt> [args] src | mlir-cpu-runner | FileCheck src`.

    For end-to-end tests: lower IR all the way to LLVM dialect, JIT it
    via mlir-cpu-runner, and FileCheck the program's stdout against
    `// CHECK*` directives in the source file. Used in stage 11.

    Args:
      name: the test target name.
      src: a .mlir file containing input IR plus `// CHECK*` directives
        describing the expected program output.
      calc_opt: this stage's calc-opt binary.
      calc_opt_args: pipeline flags for calc-opt (the lowering chain to
        produce LLVM-dialect IR).
    """
    calc_opt_args = calc_opt_args or []
    native.sh_test(
        name = name,
        srcs = ["//common:run_jit.sh"],
        args = [
            "$(location {})".format(calc_opt),
            "$(location @llvm-project//mlir:mlir-cpu-runner)",
            "$(location @llvm-project//llvm:FileCheck)",
            "$(location {})".format(src),
        ] + calc_opt_args,
        data = [
            src,
            calc_opt,
            "@llvm-project//mlir:mlir-cpu-runner",
            "@llvm-project//llvm:FileCheck",
        ],
    )

def dialect_registered_test(name, calc_opt, dialect_name):
    """Verifies that `<calc_opt> --show-dialects` lists `dialect_name`.

    Used in stage 01, where the dialect has no ops yet and the only
    observable thing is that it's registered.
    """
    native.sh_test(
        name = name,
        srcs = ["//common:check_dialect_registered.sh"],
        args = [
            "$(location {})".format(calc_opt),
            dialect_name,
        ],
        data = [calc_opt],
    )
