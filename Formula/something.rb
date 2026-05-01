class Something < Formula
  desc "Modular, high-security monitoring framework for Telegram"
  homepage "https://github.com/ilham-fauzi/something"
  head "https://github.com/ilham-fauzi/something.git", branch: "main"

  depends_on "jq"
  depends_on "curl"
  depends_on "openssl"

  def install
    # Install everything into libexec to preserve structure
    libexec.install Dir["*"]
    
    # Symlink the main binary to bin/something
    bin.install_symlink libexec/"bin/something"
  end

  def post_install
    # Initialize the structure if it's a new install
    (libexec/"config").mkpath
    (libexec/"logs").mkpath
    (libexec/"modules").mkpath
    
    # Create default config if missing
    if !File.exist?(libexec/"config/something.conf") && File.exist?(libexec/"config/something.conf.example")
      cp libexec/"config/something.conf.example", libexec/"config/something.conf"
    end
  end

  test do
    # Simple check to see if the CLI responds
    assert_match "Something Framework", shell_output("#{bin}/something help")
  end
end
