import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://deroy2112.github.io",
  base: "/proxmox-lxc-templates",
  trailingSlash: "always",
  vite: {
    plugins: [tailwindcss()],
  },
});
