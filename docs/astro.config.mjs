import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

import node from "@astrojs/node";

// https://astro.build/config
export default defineConfig({
  site: 'https://kyjor.github.io',
  base: '/JulGame.jl',
  integrations: [starlight({
    title: 'JulGame Docs',
    lastUpdated: true,
    social: {
      github: 'https://github.com/Kyjor/JulGame.jl'
    },
    sidebar: [{
      label: 'Getting Started',
      items: [
      // Each item here is one entry in the navigation menu.
      {
        label: 'What is JulGame?',
        link: '/general/what-is-julgame/'
      }]
    }, {
      label: 'Guides',
      items: [
      // Each item here is one entry in the navigation menu.
      {
        label: 'Create a Simple Game',
        link: '/guides/example/'
      }]
    }, {
      label: 'API Reference',
      autogenerate: {
        directory: 'reference',
        collapsed: true
      }
    }]
  })],
  // output: "server",
  // adapter: node({
  //   mode: "standalone"
  // })
});