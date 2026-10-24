// SPDX-FileCopyrightText: 2025 Florian Müllner <fmuellner@gnome.org>
// SPDX-License-Identifier: MIT OR LGPL-2.1-or-later

import recommended from './configs/gnome-recommended.js';
import jsdoc from './configs/gnome-jsdoc.js';
import fs from 'fs';
import path from 'path';

const pkg = JSON.parse(
    fs.readFileSync(path.resolve(import.meta.dirname, '../package.json'))
);

const plugin = {
    meta: {
        name: pkg.name,
        version: pkg.version,
    },
    configs: {
        recommended,
        jsdoc,
    },
};

export default plugin;
