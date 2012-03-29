
  if (typeof Spine === "undefined" || Spine === null) Spine = require('spine');

  Spine.Model.Local = {
    extended: function() {
      this.change(this.saveLocal);
      return this.fetch(this.loadLocal);
    },
    saveLocal: function() {
      var result;
      result = JSON.stringify({
        result: this,
        idCounter: this.idCounter
      });
      return localStorage[this.className] = result;
    },
    loadLocal: function() {
      var idCounter, load, result, _ref;
      load = localStorage[this.className];
      _ref = JSON.parse(load) || {}, result = _ref.result, idCounter = _ref.idCounter;
      this.refresh(result || [], {
        clear: true
      });
      return this.idCounter = idCounter || 0;
    }
  };

  if (typeof module !== "undefined" && module !== null) {
    module.exports = Spine.Model.Local;
  }
