(function() {
  var Proj4GlModule;

  define(['./script/proj4gl-shaders.js'], function(shaders) {
    return new Proj4GlModule(shaders);
  });

  Proj4GlModule = (function() {

    function Proj4GlModule(_shaders) {
      this._shaders = _shaders;
    }

    Proj4GlModule.prototype.projectionShaderSource = function(projName) {
      var common_source, field, fields, params, shader_params, shader_source, structure_source, type, _i, _len;
      common_source = this._shaders['proj/common.glsl'];
      if (!(common_source != null)) {
        throw 'Common library code not present in proj4gl library!';
      }
      common_source = atob(common_source);
      projName = projName.toString();
      shader_source = this._shaders["proj/" + projName + ".glsl"];
      shader_params = this._shaders["proj/" + projName + "-params.json"];
      if (!(shader_source != null) || !(shader_params != null)) {
        throw 'No such projection: ' + projName;
      }
      shader_source = atob(shader_source);
      params = [];
      structure_source = "struct " + projName + "_params {\n";
      for (type in shader_params) {
        fields = shader_params[type];
        structure_source += '  ' + type + ' ' + fields.join(', ') + ';\n';
        for (_i = 0, _len = fields.length; _i < _len; _i++) {
          field = fields[_i];
          params.push([field, type]);
        }
      }
      structure_source += '};\n';
      return {
        source: common_source + structure_source + shader_source,
        forwardsFunction: 'not_implemented',
        backwardsFunction: projName + '_backwards',
        paramsStruct: {
          source: structure_source,
          name: projName + '_params',
          params: params
        }
      };
    };

    return Proj4GlModule;

  })();

}).call(this);
