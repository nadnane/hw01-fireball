import {vec4, mat4, vec2} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;
  attrNor: number;
  attrCol: number;

  unifModel: WebGLUniformLocation;
  unifModelInvTr: WebGLUniformLocation;
  unifViewProj: WebGLUniformLocation;
  unifFireColor: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;
  canvasSize: WebGLUniformLocation;
  FBM_Octaves: WebGLUniformLocation;
  FBM_Freq: WebGLUniformLocation;
  FBM_Amp: WebGLUniformLocation;

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");
    this.attrNor = gl.getAttribLocation(this.prog, "vs_Nor");
    this.attrCol = gl.getAttribLocation(this.prog, "vs_Col");
    this.unifModel      = gl.getUniformLocation(this.prog, "u_Model");
    this.unifModelInvTr = gl.getUniformLocation(this.prog, "u_ModelInvTr");
    this.unifViewProj   = gl.getUniformLocation(this.prog, "u_ViewProj");
    this.unifFireColor      = gl.getUniformLocation(this.prog, "u_FireColor");
    this.unifTime       = gl.getUniformLocation(this.prog, "u_Time");
    this.canvasSize     = gl.getUniformLocation(this.prog, "canvasSize");
    this.FBM_Octaves    = gl.getUniformLocation(this.prog, "FBM_Octaves");
    this.FBM_Freq    = gl.getUniformLocation(this.prog, "FBM_Freq");
    this.FBM_Amp    = gl.getUniformLocation(this.prog, "FBM_Amp");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  setModelMatrix(model: mat4) {
    this.use();
    if (this.unifModel !== -1) {
      gl.uniformMatrix4fv(this.unifModel, false, model);
    }

    if (this.unifModelInvTr !== -1) {
      let modelinvtr: mat4 = mat4.create();
      mat4.transpose(modelinvtr, model);
      mat4.invert(modelinvtr, modelinvtr);
      gl.uniformMatrix4fv(this.unifModelInvTr, false, modelinvtr);
    }
  }

  setViewProjMatrix(vp: mat4) {
    this.use();
    if (this.unifViewProj !== -1) {
      gl.uniformMatrix4fv(this.unifViewProj, false, vp);
    }
  }

  setTime(time: number){
    this.use();
    if (this.unifTime !== -1){
      gl.uniform1f(this.unifTime, time);
    }
  }

  setCanvasSize(dims: vec2){
    this.use();
    if (this.canvasSize !== -1){
      gl.uniform2f(this.canvasSize, dims[0], dims[1]);
    }
  }

  setFireColor(color: vec4) {
    this.use();
    if (this.unifFireColor !== -1) {
      gl.uniform4fv(this.unifFireColor, color);
    }
  }

  setFBMOctaves(octaves: number) {
    this.use();
    if (this.FBM_Octaves !== -1) {
      gl.uniform1i(this.FBM_Octaves, octaves);
    }
  }

  setFBMFreq(freq: number) {
    this.use();
    if (this.FBM_Freq !== -1) {
      gl.uniform1f(this.FBM_Freq, freq);
    }
  }

  setFBMAmp(amp: number) {
    this.use();
    if (this.FBM_Amp !== -1) {
      gl.uniform1f(this.FBM_Amp, amp);
    }
  }

  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    if (this.attrNor != -1 && d.bindNor()) {
      gl.enableVertexAttribArray(this.attrNor);
      gl.vertexAttribPointer(this.attrNor, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);
    if (this.attrNor != -1) gl.disableVertexAttribArray(this.attrNor);
  }
};

export default ShaderProgram;
