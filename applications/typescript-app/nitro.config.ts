import { defineNitroConfig } from 'nitro/config'

export default defineNitroConfig({
  preset: 'bun',
  dev: {
    host: '0.0.0.0',
    port: 3000,
  },
  compatibilityDate: '2025-10-21',
})
