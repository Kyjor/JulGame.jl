import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

import node from "@astrojs/node";

// https://astro.build/config
export default defineConfig({
  site: 'https://kyjor.github.io',
  base: '/JulGame.jl',
  integrations: [starlight({
    title: 'JulGame Docs',
    social: {
      github: 'https://github.com/Kyjor/JulGame.jl'
    },
    sidebar: [{
      label: 'Getting Started',
      items: [
      // Each item here is one entry in the navigation menu.
      {
        label: 'What is JulGame?',
        link: '/JulGame.jl/docs/general/what-is-julgame/'
      }]
    }, {
      label: 'Guides',
      items: [
      // Each item here is one entry in the navigation menu.
      {
        label: 'Create a Simple Game',
        link: '/JulGame.jl/docs/guides/example/'
      }]
    }, {
      label: 'API Reference',
      autogenerate: {
        directory: '/JulGame.jl/docs/reference',
        collapsed: true

      }
    }]
  })],
  // output: "server",
  // adapter: node({
  //   mode: "standalone"
  // })
});
