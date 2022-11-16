{ lib, callPackage, tree-sitter, neovim, runCommand }:

self: super:

let
  generatedGrammars = callPackage ./generated.nix {
    buildGrammar = callPackage ../../../../../development/tools/parsing/tree-sitter/grammar.nix { };
  };

  generatedDerivations = lib.filterAttrs (_: lib.isDerivation) generatedGrammars;

  # add aliases so grammars from `tree-sitter` are overwritten in `withPlugins`
  # for example, for ocaml_interface, the following aliases will be added
  #   ocaml-interface
  #   tree-sitter-ocaml-interface
  #   tree-sitter-ocaml_interface
  builtGrammars = generatedGrammars // lib.listToAttrs
    (lib.concatLists (lib.mapAttrsToList
      (k: v:
        let
          replaced = lib.replaceStrings [ "_" ] [ "-" ] k;
        in
        map (lib.flip lib.nameValuePair v)
          ([ "tree-sitter-${k}" ] ++ lib.optionals (k != replaced) [
            replaced
            "tree-sitter-${replaced}"
          ]))
      generatedDerivations));

  allGrammars = lib.attrValues generatedDerivations;

  # Usage:
  # pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [ p.c p.java ... ])
  # or for all grammars:
  # pkgs.vimPlugins.nvim-treesitter.withAllGrammars
  withPlugins =
    grammarFn: self.nvim-treesitter.overrideAttrs (_: {
      postPatch =
        let
          grammars = tree-sitter.withPlugins (ps: grammarFn (ps // builtGrammars));
        in
        ''
          rm -r parser
          ln -s ${grammars} parser
        '';
    });

  withAllGrammars = withPlugins (_: allGrammars);
in

{
  passthru = {
    inherit builtGrammars allGrammars withPlugins withAllGrammars;

    tests.check-queries =
      let
        nvimWithAllGrammars = neovim.override {
          configure.packages.all.start = [ withAllGrammars ];
        };
      in
      runCommand "nvim-treesitter-check-queries"
        {
          nativeBuildInputs = [ nvimWithAllGrammars ];
          CI = true;
        }
        ''
          touch $out
          export HOME=$(mktemp -d)
          ln -s ${withAllGrammars}/CONTRIBUTING.md .

          nvim --headless "+luafile ${withAllGrammars}/scripts/check-queries.lua" | tee log

          if grep -q Warning log; then
            echo "Error: warnings were emitted by the check"
            exit 1
          fi
        '';
  };

  meta.maintainers = with lib.maintainers; [ figsoda ];
}

