/* Generated file. */
args @ { fetchurl, ... }:
rec {
  baseName = "lack-component";
  version = "lack-20211209-git";

  description = "System lacks description";

  deps = [ ];

  src = fetchurl {
    url = "http://beta.quicklisp.org/archive/lack/2021-12-09/lack-20211209-git.tgz";
    sha256 = "0vd36hjcf98s9slkm6rmgsa7r10wvzl9s4xhfmcwh7qv7jxdgkhg";
  };

  packageName = "lack-component";

  asdFilesToKeep = ["lack-component.asd"];
  overrides = x: x;
}
/* (SYSTEM lack-component DESCRIPTION System lacks description SHA256
    0vd36hjcf98s9slkm6rmgsa7r10wvzl9s4xhfmcwh7qv7jxdgkhg URL
    http://beta.quicklisp.org/archive/lack/2021-12-09/lack-20211209-git.tgz MD5
    610b1aea0280193d6f125aa1317a2d79 NAME lack-component FILENAME
    lack-component DEPS NIL DEPENDENCIES NIL VERSION lack-20211209-git SIBLINGS
    (lack-app-directory lack-app-file lack-middleware-accesslog
     lack-middleware-auth-basic lack-middleware-backtrace lack-middleware-csrf
     lack-middleware-mount lack-middleware-session lack-middleware-static
     lack-request lack-response lack-session-store-dbi lack-session-store-redis
     lack-test lack-util-writer-stream lack-util lack t-lack-component
     t-lack-middleware-accesslog t-lack-middleware-auth-basic
     t-lack-middleware-backtrace t-lack-middleware-csrf t-lack-middleware-mount
     t-lack-middleware-session t-lack-middleware-static t-lack-request
     t-lack-session-store-dbi t-lack-session-store-redis t-lack-util t-lack)
    PARASITES NIL) */
