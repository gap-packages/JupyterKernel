// Notebook Extension to allow GAP Mode on Jupyter

/* global define */

define([
  'base/js/namespace',
  'nbextensions/gap-mode/gap'
], function () {
  'use strict';

  return {
    load_ipython_extension: function () {
      console.log('Loading GAP Mode for Codemirror...');
    }
  };

});
