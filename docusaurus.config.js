// @ts-check
const {themes} = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'DS30 Docs',
  tagline: 'GTM Architecture & UPD Analyzer',
  favicon: 'img/favicon.png',

  // TODO: confirmar o domínio (plano §10). Entra no HTML gerado: trocar exige build novo.
  url: 'https://ds30-docs.dp6.io',
  baseUrl: '/',

  // Conteúdo interno atrás de IAP (dp6.com.br): nunca indexar. Par com static/robots.txt e o
  // X-Robots-Tag do nginx.conf.
  noIndex: true,
  headTags: [{tagName: 'meta', attributes: {name: 'robots', content: 'noindex, nofollow'}}],

  organizationName: 'dp6',
  projectName: 'ds30-docs',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'pt-BR',
    locales: ['pt-BR', 'en', 'es'],
    localeConfigs: {
      'pt-BR': {label: 'Português', htmlLang: 'pt-BR'},
      en: {label: 'English'},
      es: {label: 'Español'},
    },
  },

  markdown: {mermaid: true},

  plugins: ['docusaurus-plugin-image-zoom'],

  themes: [
    '@docusaurus/theme-mermaid',
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        language: ['en', 'es', 'pt'],
        docsRouteBasePath: '/docs',
        indexBlog: false,
      },
    ],
  ],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {sidebarPath: require.resolve('./sidebars.js')},
        blog: false,
        theme: {customCss: require.resolve('./src/css/custom.css')},
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {defaultMode: 'dark', disableSwitch: false, respectPrefersColorScheme: false},
      zoom: {selector: '.markdown img:not(.no-zoom)'},
      navbar: {
        title: 'DS30 Docs',
        // "dp" branco exige fundo escuro: a navbar é preta nos dois temas (custom.css).
        logo: {alt: 'DP6', src: 'img/dp6-logo-branco-amarelo.png'},
        items: [
          {type: 'docSidebar', sidebarId: 'guiaDoUsuario', label: 'Guia do usuário', position: 'left'},
          {type: 'docSidebar', sidebarId: 'documentacaoDoProjeto', label: 'Documentação do projeto', position: 'left'},
          {type: 'search', position: 'right'},
          {type: 'localeDropdown', position: 'right'},
        ],
      },
      footer: {style: 'dark', copyright: `Copyright © ${new Date().getFullYear()} DP6 · DS30 Docs`},
      prism: {theme: themes.github, darkTheme: themes.dracula},
    }),
};

module.exports = config;
