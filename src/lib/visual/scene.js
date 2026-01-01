/**
 * Calm Audio Landscape
 * Simple layered ribbons + voice markers that drift across the scene.
 */

import * as THREE from 'three';

const LANDSCAPE_WIDTH = 18;
const LANDSCAPE_SEGMENTS = 120;

class LandscapeBand {
  constructor(scene, options) {
    const {
      baseY,
      thickness,
      color,
      z,
      noiseScale,
      driftSpeed,
      baseAmplitude,
      energyAmplitude
    } = options;

    this.baseY = baseY;
    this.thickness = thickness;
    this.z = z;
    this.noiseScale = noiseScale;
    this.driftSpeed = driftSpeed;
    this.baseAmplitude = baseAmplitude;
    this.energyAmplitude = energyAmplitude;

    this.energySmooth = 0;
    this.seed = Math.random() * 10;

    const vertices = (LANDSCAPE_SEGMENTS + 1) * 2;
    this.positions = new Float32Array(vertices * 3);
    this.geometry = new THREE.BufferGeometry();
    this.geometry.setAttribute('position', new THREE.BufferAttribute(this.positions, 3));

    const indices = [];
    for (let i = 0; i < LANDSCAPE_SEGMENTS; i++) {
      const a = i * 2;
      const b = i * 2 + 1;
      const c = i * 2 + 2;
      const d = i * 2 + 3;
      indices.push(a, b, c, b, d, c);
    }
    this.geometry.setIndex(indices);

    this.material = new THREE.MeshBasicMaterial({
      color: new THREE.Color(color),
      transparent: true,
      opacity: 0.9
    });

    this.mesh = new THREE.Mesh(this.geometry, this.material);
    this.mesh.position.z = this.z;
    this.mesh.frustumCulled = false;
    scene.add(this.mesh);
  }

  noise(x, time) {
    const t = time * this.driftSpeed;
    const p = x * this.noiseScale + this.seed;
    return (
      Math.sin(p + t) * 0.6 +
      Math.sin(p * 0.5 - t * 0.7 + this.seed * 1.7) * 0.4
    );
  }

  update(time, energy, relief, flow) {
    this.energySmooth += (energy - this.energySmooth) * 0.08;

    const amplitude = this.baseAmplitude + this.energySmooth * this.energyAmplitude * relief;
    const driftTime = time * (0.2 + flow * 0.5);

    for (let i = 0; i <= LANDSCAPE_SEGMENTS; i++) {
      const x = -LANDSCAPE_WIDTH / 2 + (LANDSCAPE_WIDTH * i) / LANDSCAPE_SEGMENTS;
      const n = this.noise(x, driftTime);
      const topY = this.baseY + n * amplitude;
      const bottomY = topY - this.thickness;

      const idx = i * 6;
      this.positions[idx] = x;
      this.positions[idx + 1] = topY;
      this.positions[idx + 2] = 0;

      this.positions[idx + 3] = x;
      this.positions[idx + 4] = bottomY;
      this.positions[idx + 5] = 0;
    }

    this.geometry.attributes.position.needsUpdate = true;
  }

  dispose(scene) {
    scene.remove(this.mesh);
    this.geometry.dispose();
    this.material.dispose();
  }
}

class VoiceMarker {
  constructor(id, color, scene) {
    this.id = id;
    this.baseColor = new THREE.Color(...color);
    this.energySmooth = 0;
    this.inactiveFrames = 0;

    this.speed = 0.5 + Math.random() * 0.35;
    this.x = -LANDSCAPE_WIDTH / 2 + Math.random() * LANDSCAPE_WIDTH;
    this.y = 0;
    this.z = 0.6;
    this.seed = Math.random() * 5;

    const sphereGeo = new THREE.SphereGeometry(0.16, 18, 18);
    this.sphereMat = new THREE.MeshBasicMaterial({
      color: this.baseColor,
      transparent: true,
      opacity: 0.9
    });
    this.sphere = new THREE.Mesh(sphereGeo, this.sphereMat);
    scene.add(this.sphere);

    this.trailLength = 18;
    this.trailPositions = new Float32Array(this.trailLength * 3);
    for (let i = 0; i < this.trailLength; i++) {
      const idx = i * 3;
      this.trailPositions[idx] = this.x;
      this.trailPositions[idx + 1] = this.y;
      this.trailPositions[idx + 2] = this.z;
    }
    this.trailGeometry = new THREE.BufferGeometry();
    this.trailGeometry.setAttribute('position', new THREE.BufferAttribute(this.trailPositions, 3));
    this.trailMaterial = new THREE.LineBasicMaterial({
      color: this.baseColor,
      transparent: true,
      opacity: 0.5
    });
    this.trail = new THREE.Line(this.trailGeometry, this.trailMaterial);
    scene.add(this.trail);
  }

  update(freqNorm, energy, time, flow, dt) {
    this.inactiveFrames = 0;
    this.energySmooth += (energy - this.energySmooth) * 0.18;

    const targetY = (freqNorm - 0.5) * 5.2 + Math.sin(time * 0.4 + this.seed) * 0.2;
    this.y += (targetY - this.y) * 0.06;

    const speed = this.speed * (0.4 + flow * 0.6) * (0.6 + this.energySmooth * 0.5);
    this.x += speed * dt * 4;

    if (this.x > LANDSCAPE_WIDTH / 2 + 1.5) {
      this.x = -LANDSCAPE_WIDTH / 2 - 1.5;
    }

    const brightness = 0.6 + this.energySmooth * 0.9;
    this.sphereMat.color.copy(this.baseColor).multiplyScalar(brightness);
    this.sphereMat.opacity = 0.7 + this.energySmooth * 0.3;
    this.sphere.position.set(this.x, this.y, this.z);
    this.sphere.scale.setScalar(0.7 + this.energySmooth * 0.9);

    this.updateTrail();
  }

  decay(time, flow, dt) {
    this.inactiveFrames += 1;
    this.energySmooth *= 0.97;

    const drift = this.speed * (0.3 + flow * 0.2);
    this.x += drift * dt * 3;

    if (this.x > LANDSCAPE_WIDTH / 2 + 1.5) {
      this.x = -LANDSCAPE_WIDTH / 2 - 1.5;
    }

    const targetY = this.y + Math.sin(time * 0.2 + this.seed) * 0.02;
    this.y += (targetY - this.y) * 0.02;

    this.sphereMat.opacity = 0.4 + this.energySmooth * 0.2;
    this.sphere.position.set(this.x, this.y, this.z);
    this.sphere.scale.setScalar(0.6 + this.energySmooth * 0.5);

    this.updateTrail();
  }

  updateTrail() {
    for (let i = this.trailLength - 1; i > 0; i--) {
      const idx = i * 3;
      const prev = (i - 1) * 3;
      this.trailPositions[idx] = this.trailPositions[prev];
      this.trailPositions[idx + 1] = this.trailPositions[prev + 1];
      this.trailPositions[idx + 2] = this.trailPositions[prev + 2];
    }
    this.trailPositions[0] = this.x;
    this.trailPositions[1] = this.y;
    this.trailPositions[2] = this.z;

    this.trailGeometry.attributes.position.needsUpdate = true;
    this.trailMaterial.opacity = 0.25 + this.energySmooth * 0.35;
  }

  dispose(scene) {
    scene.remove(this.sphere);
    scene.remove(this.trail);
    this.sphere.geometry.dispose();
    this.sphereMat.dispose();
    this.trailGeometry.dispose();
    this.trailMaterial.dispose();
  }
}

let bands = [];
let voiceMarkers = new Map();

export async function createScene(container) {
  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    powerPreference: 'high-performance',
    alpha: true
  });

  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.setClearColor(0x000000, 0);

  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0x06080b, 6, 22);

  const camera = new THREE.PerspectiveCamera(
    45,
    window.innerWidth / window.innerHeight,
    0.1,
    50
  );
  camera.position.set(0, 0.4, 10);
  camera.lookAt(0, 0, 0);

  bands = [
    new LandscapeBand(scene, {
      baseY: 2.6,
      thickness: 1.4,
      color: 0x2b4f8e,
      z: -2.2,
      noiseScale: 0.6,
      driftSpeed: 0.25,
      baseAmplitude: 0.5,
      energyAmplitude: 1.1
    }),
    new LandscapeBand(scene, {
      baseY: 0.9,
      thickness: 1.0,
      color: 0x365da6,
      z: -1.1,
      noiseScale: 0.85,
      driftSpeed: 0.3,
      baseAmplitude: 0.35,
      energyAmplitude: 0.9
    }),
    new LandscapeBand(scene, {
      baseY: -1.3,
      thickness: 0.8,
      color: 0x2f7b3f,
      z: -0.2,
      noiseScale: 1.1,
      driftSpeed: 0.35,
      baseAmplitude: 0.18,
      energyAmplitude: 0.6
    }),
    new LandscapeBand(scene, {
      baseY: -2.9,
      thickness: 1.0,
      color: 0x1f4b2a,
      z: 0.6,
      noiseScale: 0.9,
      driftSpeed: 0.28,
      baseAmplitude: 0.12,
      energyAmplitude: 0.45
    })
  ];

  voiceMarkers = new Map();

  const onResize = () => {
    const width = window.innerWidth;
    const height = window.innerHeight;
    renderer.setSize(width, height);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
  };

  window.addEventListener('resize', onResize);

  const startTime = performance.now();

  return {
    renderer,
    scene,
    camera,
    startTime,
    lastFrameTime: startTime,
    onResize
  };
}

export function updateScene(context, features, vibe) {
  const { renderer, scene, camera, startTime } = context;
  const now = performance.now();
  const time = (now - startTime) / 1000;
  const dt = Math.min(0.05, (now - context.lastFrameTime) / 1000 || 0.016);
  context.lastFrameTime = now;

  const flow = 1 - (vibe?.viscosity ?? 0.3);
  const relief = 0.45 + (vibe?.harmonics ?? 0.2) * 0.7;
  const depth = vibe?.atmosphere ?? 0.4;

  const bandEnergies = features?.bandEnergies || new Float32Array(6);

  const bandEnergyMap = [
    bandEnergies[1] || 0,
    bandEnergies[2] || 0,
    bandEnergies[0] || 0,
    bandEnergies[0] || 0
  ];

  bands.forEach((band, index) => {
    band.update(time, bandEnergyMap[index], relief, flow);
  });

  const voices = features?.voices || [];
  const activeIds = new Set();

  for (const voice of voices) {
    activeIds.add(voice.id);

    if (!voiceMarkers.has(voice.id)) {
      voiceMarkers.set(voice.id, new VoiceMarker(voice.id, voice.color, scene));
    }

    const marker = voiceMarkers.get(voice.id);
    marker.update(voice.freqNorm, voice.energy, time, flow, dt);
  }

  for (const [id, marker] of voiceMarkers.entries()) {
    if (!activeIds.has(id)) {
      marker.decay(time, flow, dt);
      if (marker.inactiveFrames > 240 && marker.energySmooth < 0.02) {
        marker.dispose(scene);
        voiceMarkers.delete(id);
      }
    }
  }

  scene.fog.near = 4 + depth * 4;
  scene.fog.far = 16 + depth * 12;

  camera.position.x = Math.sin(time * 0.15) * 0.2;
  camera.position.y = Math.cos(time * 0.12) * 0.15;
  camera.lookAt(0, 0, 0);

  renderer.render(scene, camera);
}

export function disposeScene(context) {
  const { renderer, scene, onResize } = context;

  window.removeEventListener('resize', onResize);

  for (const marker of voiceMarkers.values()) {
    marker.dispose(scene);
  }
  voiceMarkers.clear();

  bands.forEach((band) => band.dispose(scene));
  bands = [];

  renderer.dispose();
}
