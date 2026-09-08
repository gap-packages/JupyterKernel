import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';
import { IEditorLanguageRegistry } from '@jupyterlab/codemirror';
import { LanguageSupport } from '@codemirror/language';

import { gapLanguage } from './gap-mode';

const plugin: JupyterFrontEndPlugin<void> = {
  id: 'jupyterlab-gap-mode:plugin',
  description: 'GAP syntax highlighting for JupyterLab and Notebook 7.',
  autoStart: true,
  requires: [IEditorLanguageRegistry],
  activate: (
    _app: JupyterFrontEnd,
    registry: IEditorLanguageRegistry
  ): void => {
    registry.addLanguage({
      name: 'GAP',
      alias: ['gap', 'GAP 4'],
      mime: 'text/x-gap',
      extensions: ['g', 'gd', 'gi', 'gap'],
      support: new LanguageSupport(gapLanguage)
    });
  }
};

export default plugin;
