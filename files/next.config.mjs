const isProd = process.env.NODE_ENV === 'production';

/** @type {import('next').NextConfig} */
const nextConfig = {
  devIndicators: false,
  // Allow the VM's public host to load Next.js development assets (HMR/fonts).
  allowedDevOrigins: ['84.13.130.4'],
  output: 'standalone',
  compress: false,
  // Placeholder is only baked in production builds. The container's entrypoint
  // replaces it with the real BASE_PATH env var at runtime. In dev (`next dev`),
  // we skip it so everything works against localhost without needing the sed.
  ...(isProd && { assetPrefix: '/__BASE_PATH_PLACEHOLDER__' }),
  images: {
    ...(isProd && { loader: 'custom', loaderFile: './imageLoader.js' }),
    dangerouslyAllowSVG: true,
    contentSecurityPolicy: "default-src 'self'; script-src 'none'; sandbox;",
  },
};

export default nextConfig;
