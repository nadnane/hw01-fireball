import { vec2, vec3, vec4 } from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import { setGL } from './globals';
import ShaderProgram, { Shader } from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  FBMOctaves: 8,
  FBMFreq: 16.0,
  FBMAmp: 1.0,
  'Load Scene': loadScene, // A function pointer, essentially
  'Reset Scene': resetScene,
  FireColor: [191, 70, 5, 1],
  BackgroundColor: [4, 4, 38, 1],
};

const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

let fire: Icosphere;
let outerFlame: Icosphere;
let square: Square;
let cube: Cube;
let prevTesselations: number = 5;
let time = 0;

function resetScene(){
  camera.reset();
}

function loadScene() {
  fire = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  fire.create();

  outerFlame = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  outerFlame.create();

  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();

  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();

  time = 0;
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'FBMOctaves', 0, 16).step(1);
  gui.add(controls, 'FBMFreq', 0.0, 32.0).step(0.1);
  gui.add(controls, 'FBMAmp', 0.0, 5.0).step(0.1);
  gui.add(controls, 'Load Scene');
  gui.addColor(controls, 'FireColor');
  gui.addColor(controls, 'BackgroundColor')
  gui.add(controls, 'Reset Scene');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement>document.getElementById('canvas');
  const gl = <WebGL2RenderingContext>canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const renderer = new OpenGLRenderer(canvas);

  gl.enable(gl.DEPTH_TEST);

  // const lambert = new ShaderProgram([
  //   new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
  //   new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert-frag.glsl')),
  // ]);

  const fireShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/fire-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/fire-frag.glsl')),
  ]);

  const outerFireShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/outerfire-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/outerfire-frag.glsl')),
  ]);

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if (controls.tesselations != prevTesselations) {
      prevTesselations = controls.tesselations;

      outerFlame = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      outerFlame.create();

      fire = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      fire.create();
    }

    gl.disable(gl.DEPTH_TEST);

    let fireColor = vec4.fromValues(
      controls.FireColor[0] / 255.0, 
      controls.FireColor[1] / 255.0, 
      controls.FireColor[2] / 255.0, 
      controls.FireColor[3]);

      renderer.setClearColor(
        controls.BackgroundColor[0] / 255.0,
        controls.BackgroundColor[1] / 255.0, 
        controls.BackgroundColor[2] / 255.0, 
        controls.BackgroundColor[3] 
      );

    fireShader.setTime(time++);
    outerFireShader.setTime(time++);
    fireShader.setCanvasSize(vec2.fromValues(canvas.width, canvas.height));
    outerFireShader.setCanvasSize(vec2.fromValues(canvas.width, canvas.height));

    fireShader.setFBMOctaves(controls.FBMOctaves);
    fireShader.setFBMFreq(controls.FBMFreq);
    fireShader.setFBMAmp(controls.FBMAmp);

    outerFireShader.setFBMOctaves(controls.FBMOctaves);
    outerFireShader.setFBMFreq(controls.FBMFreq);
    outerFireShader.setFBMAmp(controls.FBMAmp);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_COLOR);

    renderer.render(
      camera, 
      outerFireShader,
      [
        outerFlame,
      ], 
      fireColor,
      controls.FBMOctaves,
      controls.FBMFreq,
      controls.FBMAmp,
      );

    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE);

    renderer.render(
      camera, 
      fireShader,
      [
        fire,
      ], 
      fireColor,
      controls.FBMOctaves,
      controls.FBMFreq,
      controls.FBMAmp,
      );

    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function () {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
