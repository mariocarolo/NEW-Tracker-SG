import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Vite's React plugin compiles the .jsx files (including the verbatim port).
export default defineConfig({
  plugins: [react()],
});
