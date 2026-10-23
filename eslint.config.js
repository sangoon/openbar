import gnome from './tools/eslint-config-gnome/src/index.js';

export default [
    ...gnome.configs.recommended,
    {
        languageOptions: {
            globals: {
                global: 'readonly',
                console: 'readonly',
                setTimeout: 'readonly',
                clearTimeout: 'readonly',
                _: 'readonly',
                C_: 'readonly',
                N_: 'readonly',
                ngettext: 'readonly',
                pgettext: 'readonly',
            },
        },
    },
];
