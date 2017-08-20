// Notebook Extension to allow GAP Mode on Jupyter

define([
  'base/js/namespace',
  './gap'
], function (Jupyter) {
  "use strict";

  return {
    load_ipython_extension: function () {
      console.log('Loading GAP Mode...');
    }
  };

});
