define ['./script/proj4gl-shaders.js'], (shaders) -> new Proj4GlModule shaders

class Proj4GlModule
  constructor: (@_shaders) ->

  # return an object with several fields: 'source', the source code of the GLSL
  # shader for the specified projection type 'paramsStruct' is a GLSL
  # structure definition for the parameters where the structure is called
  # paramsStruct.name and the source code is paramsStruct.source and the 
  # parameters are described as ['name', 'type'] pairs in paramsStruct.params
  projectionShaderSource: (projName) ->
    common_source = @_shaders['proj/common.glsl']
    if not common_source?
      throw 'Common library code not present in proj4gl library!'
    common_source = atob common_source

    projName = projName.toString()

    # retrieve the GLSL source and parameters description from the database
    shader_source = @_shaders["proj/#{ projName }.glsl"]
    shader_params = @_shaders["proj/#{ projName }-params.json"]
    if not shader_source? or not shader_params?
      throw 'No such projection: ' + projName

    # decode source from base64
    shader_source = atob shader_source

    # construct a structure description for the projection parameters
    params = []
    structure_source = "struct #{ projName }_params {\n"
    for type, fields of shader_params
      structure_source += '  ' + type + ' ' + fields.join(', ') + ';\n'
      for field in fields
        params.push [field, type]
    structure_source += '};\n'
    
    {
      source: common_source + structure_source + shader_source,
      forwardsFunction: 'not_implemented',
      backwardsFunction: projName + '_backwards',
      paramsStruct: { source: structure_source, name: projName + '_params', params: params },
    }

# vim:sw=2:sts=2:et
