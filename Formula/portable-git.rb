require File.expand_path("../../Abstract/portable-formula", __FILE__)

class PortableGit < PortableFormula
  desc "Portable git"
  homepage "https://git-scm.com"
  url "https://www.kernel.org/pub/software/scm/git/git-2.8.2.tar.xz"
  sha256 "ec0283d78a0f1c8408c5fd43610697b953fbaafe4077bb1e41446a9ee3a2f83d"

  depends_on "zlib" => :build unless OS.mac?
  depends_on "portable-curl" => :build
  depends_on "portable-expat" => :build if OS.linux?

  def install
    zlib = Formula["zlib"]
    curl = Formula["portable-curl"]
    expat = Formula["portable-expat"]

    ENV.append "LDFLAGS", "-Wl,-search_paths_first"
    ENV.universal_binary if build.with? "universal"

    # Statically link with zlib.
    ENV.append "LDFLAGS", "-L#{zlib.opt_lib}" unless OS.mac?

    # Git Makefile doesn't support to link static libcurl.
    inreplace "Makefile", "$(CURL_LIBCURL)", `#{curl.opt_bin/"curl-config"} --static-libs`.chomp

    # If these things are installed, tell Git build system to not use them
    ENV["NO_FINK"] = "1"
    ENV["NO_DARWIN_PORTS"] = "1"
    ENV["V"] = "1" # build verbosely
    ENV["NO_R_TO_GCC_LINKER"] = "1" # pass arguments to LD correctly
    ENV["PYTHON_PATH"] = which "python"
    ENV["PERL_PATH"] = which "perl"
    ENV["NO_PERL_MAKEMAKER"] = "1"
    ENV["NO_GETTEXT"] = "1"
    ENV["NO_TCLTK"] = "1"
    ENV["NO_OPENSSL"] = "1"
    ENV["EXPATDIR"] = expat.opt_prefix if OS.linux?
    args = %W[
      prefix=#{prefix}
      CC=#{ENV.cc}
      CFLAGS=#{ENV.cflags}
      LDFLAGS=#{ENV.ldflags}
    ]
    system "make", "install", *args

    (libexec/"bin").mkpath
    (libexec/"bin").install bin/"git"
    (bin/"git").write <<-EOS.undent
      #!/bin/bash
      GIT_LIBEXEC="$(cd "${0%/*}/.." && pwd -P)/libexec"
      GIT_SSL_CAINFO="$GIT_LIBEXEC/cert.pem" exec "$GIT_LIBEXEC/bin/git" "$@"
    EOS
    cp curl.opt_libexec/"cert.pem", libexec/"cert.pem"
  end

  test do
    cp_r Dir["#{prefix}/*"], testpath
    ENV["PATH"] = "/usr/bin:/bin"
    ENV["GIT_CURL_VERBOSE"] = "1"
    system testpath/"bin/git", "clone", "https://github.com/isaacs/github"
  end
end
