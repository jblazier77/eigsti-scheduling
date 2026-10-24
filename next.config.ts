import type { NextConfig } from 'next';

const checkDirectory=process.env.EIGSTI_BUILD_DIRECTORY;
const freshCheck=!!checkDirectory&&/^\.next-check-[a-f0-9]{16}$/.test(checkDirectory);
const config: NextConfig = {
  // Optional fresh output for verification when Windows holds an older cache open.
  distDir: freshCheck?checkDirectory:checkDirectory==='.next-check'?'.next-check':'.next',
  typescript: { tsconfigPath: freshCheck?'.tsconfig-check.json':'tsconfig.json' },
  poweredByHeader: false,
  experimental: { serverActions: { bodySizeLimit: '32kb' } },
  async headers() {
    return [{ source: '/:path*', headers: [
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      { key: 'X-Frame-Options', value: 'DENY' },
      { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' }
    ] }];
  }
};
export default config;
