import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@gs/shared"],
  outputFileTracingRoot: path.join(__dirname, "../.."),
  experimental: {
    staleTimes: {
      dynamic: 180,
      static: 180,
    },
    serverActions: {
      allowedOrigins: [
        "*.netlify.app",
        "gssolucoestec.com.br",
        "*.gssolucoestec.com.br",
      ],
    },
  },
};

export default nextConfig;
