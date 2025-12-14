// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
  // State
  const state = {
    images: [null, null],
    mergeMode: 'vertical',
    spacing: 0,
    backgroundColor: '#000000',
    overlayPosition: 'center',
    offsetX: 0,
    offsetY: 0,
    scale: 100,
    opacity: 100,
    showControls: true,
    hideTimeout: null
  };

  // Elements
  const els = {
    topBar: document.getElementById('topBar'),
    bottomBar: document.getElementById('bottomBar'),
    settingsPanel: document.getElementById('settingsPanel'),
    uploadContainer: document.getElementById('uploadContainer'),
    canvasContainer: document.getElementById('canvasContainer'),
    canvas: document.getElementById('mergedCanvas'),
    fileInput1: document.getElementById('fileInput1'),
    fileInput2: document.getElementById('fileInput2'),
    uploadBox1: document.getElementById('uploadBox1'),
    uploadBox2: document.getElementById('uploadBox2'),
    preview1: document.getElementById('preview1'),
    preview2: document.getElementById('preview2'),
    settingsBtn: document.getElementById('settingsBtn'),
    clearBtn: document.getElementById('clearBtn'),
    toggleModeBtn: document.getElementById('toggleModeBtn'),
    downloadBtn: document.getElementById('downloadBtn'),
    mergeSettings: document.getElementById('mergeSettings'),
    overlaySettings: document.getElementById('overlaySettings'),
    spacingSlider: document.getElementById('spacingSlider'),
    spacingValue: document.getElementById('spacingValue'),
    colorPicker: document.getElementById('colorPicker'),
    colorText: document.getElementById('colorText'),
    offsetXSlider: document.getElementById('offsetXSlider'),
    offsetXValue: document.getElementById('offsetXValue'),
    offsetYSlider: document.getElementById('offsetYSlider'),
    offsetYValue: document.getElementById('offsetYValue'),
    scaleSlider: document.getElementById('scaleSlider'),
    scaleValue: document.getElementById('scaleValue'),
    opacitySlider: document.getElementById('opacitySlider'),
    opacityValue: document.getElementById('opacityValue'),
    modeText: document.getElementById('modeText'),
    currentMode: document.getElementById('currentMode')
  };

  // Auto-hide controls
  function resetAutoHide() {
    state.showControls = true;
    els.topBar.classList.remove('hidden');
    if (state.images[0] && state.images[1]) {
      els.bottomBar.classList.remove('hidden');
    }

    clearTimeout(state.hideTimeout);
    if (!els.settingsPanel.classList.contains('show')) {
      state.hideTimeout = setTimeout(() => {
        els.topBar.classList.add('hidden');
        els.bottomBar.classList.add('hidden');
      }, 3000);
    }
  }

  // Load image
  function loadImage(file, index) {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        state.images[index] = img;
        updatePreview(index);
        if (state.images[0] && state.images[1]) {
          composeImages();
          els.uploadContainer.style.display = 'none';
          els.canvasContainer.style.display = 'flex';
          els.bottomBar.classList.remove('hidden');
        }
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
  }

  // Update preview
  function updatePreview(index) {
    const preview = index === 0 ? els.preview1 : els.preview2;
    const box = index === 0 ? els.uploadBox1 : els.uploadBox2;
    
    const label = state.mergeMode === 'overlay' 
      ? (index === 0 ? 'Background' : 'Overlay') 
      : `Image ${index + 1}`;
    
    if (state.images[index]) {
      box.classList.add('has-image');
      preview.innerHTML = `
        <img src="${state.images[index].src}" class="preview-img" alt="Preview ${index + 1}">
        <p class="upload-status">${label} loaded</p>
      `;
    } else {
      box.classList.remove('has-image');
      preview.innerHTML = `
        <svg class="icon icon-lg" viewBox="0 0 24 24" stroke="currentColor" style="opacity: 0.4; margin-bottom: 8px;">
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
          <circle cx="8.5" cy="8.5" r="1.5"></circle>
          <polyline points="21 15 16 10 5 21"></polyline>
        </svg>
        <p class="upload-prompt">Upload ${label}</p>
        <p class="upload-hint">Tap to select</p>
      `;
    }
  }

  // Calculate overlay position
  function calculateOverlayPosition(bgWidth, bgHeight, overlayWidth, overlayHeight) {
    let x = 0, y = 0;
    
    switch(state.overlayPosition) {
      case 'top-left':
        x = 0; y = 0;
        break;
      case 'top-center':
        x = (bgWidth - overlayWidth) / 2; y = 0;
        break;
      case 'top-right':
        x = bgWidth - overlayWidth; y = 0;
        break;
      case 'center-left':
        x = 0; y = (bgHeight - overlayHeight) / 2;
        break;
      case 'center':
        x = (bgWidth - overlayWidth) / 2; y = (bgHeight - overlayHeight) / 2;
        break;
      case 'center-right':
        x = bgWidth - overlayWidth; y = (bgHeight - overlayHeight) / 2;
        break;
      case 'bottom-left':
        x = 0; y = bgHeight - overlayHeight;
        break;
      case 'bottom-center':
        x = (bgWidth - overlayWidth) / 2; y = bgHeight - overlayHeight;
        break;
      case 'bottom-right':
        x = bgWidth - overlayWidth; y = bgHeight - overlayHeight;
        break;
    }
    
    return { x: x + state.offsetX, y: y + state.offsetY };
  }

  // Compose images
  function composeImages() {
    const ctx = els.canvas.getContext('2d');
    const img1 = state.images[0];
    const img2 = state.images[1];

    if (!img1 || !img2) return;

    if (state.mergeMode === 'overlay') {
      // Overlay mode: img1 is background, img2 is overlay
      const bgWidth = img1.width;
      const bgHeight = img1.height;
      
      // Calculate scaled overlay dimensions
      const scaleFactor = state.scale / 100;
      const overlayWidth = img2.width * scaleFactor;
      const overlayHeight = img2.height * scaleFactor;
      
      els.canvas.width = bgWidth;
      els.canvas.height = bgHeight;
      
      // Draw background
      ctx.drawImage(img1, 0, 0);
      
      // Calculate overlay position
      const pos = calculateOverlayPosition(bgWidth, bgHeight, overlayWidth, overlayHeight);
      
      // Set overlay opacity
      ctx.globalAlpha = state.opacity / 100;
      
      // Draw overlay
      ctx.drawImage(img2, pos.x, pos.y, overlayWidth, overlayHeight);
      
      // Reset alpha
      ctx.globalAlpha = 1.0;
      
    } else {
      // Merge mode (vertical/horizontal)
      let width, height;

      if (state.mergeMode === 'vertical') {
        width = Math.max(img1.width, img2.width);
        height = img1.height + img2.height + state.spacing;
      } else {
        width = img1.width + img2.width + state.spacing;
        height = Math.max(img1.height, img2.height);
      }

      els.canvas.width = width;
      els.canvas.height = height;

      ctx.fillStyle = state.backgroundColor;
      ctx.fillRect(0, 0, width, height);

      if (state.mergeMode === 'vertical') {
        const x1 = (width - img1.width) / 2;
        const x2 = (width - img2.width) / 2;
        ctx.drawImage(img1, x1, 0);
        ctx.drawImage(img2, x2, img1.height + state.spacing);
      } else {
        const y1 = (height - img1.height) / 2;
        const y2 = (height - img2.height) / 2;
        ctx.drawImage(img1, 0, y1);
        ctx.drawImage(img2, img1.width + state.spacing, y2);
      }
    }
  }

  // Download image
  function downloadImage() {
    els.canvas.toBlob((blob) => {
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${state.mergeMode}-${Date.now()}.png`;
      a.click();
      URL.revokeObjectURL(url);
    });
  }

  // Clear images
  function clearImages() {
    state.images = [null, null];
    els.fileInput1.value = '';
    els.fileInput2.value = '';
    updatePreview(0);
    updatePreview(1);
    els.uploadContainer.style.display = 'block';
    els.canvasContainer.style.display = 'none';
    els.bottomBar.classList.add('hidden');
  }

  // Set merge mode
  function setMergeMode(mode) {
    state.mergeMode = mode;
    
    // Update UI text
    if (mode === 'overlay') {
      els.modeText.textContent = 'overlay';
      els.currentMode.textContent = 'Overlay';
      els.mergeSettings.classList.add('hide');
      els.overlaySettings.classList.add('show');
    } else {
      els.modeText.textContent = `merge ${mode}`;
      els.currentMode.textContent = mode.charAt(0).toUpperCase() + mode.slice(1);
      els.mergeSettings.classList.remove('hide');
      els.overlaySettings.classList.remove('show');
    }
    
    // Update mode buttons
    document.querySelectorAll('.mode-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.mode === mode);
    });

    // Update preview labels
    updatePreview(0);
    updatePreview(1);

    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  }

  // Cycle through modes
  function cycleMode() {
    const modes = ['vertical', 'horizontal', 'overlay'];
    const currentIndex = modes.indexOf(state.mergeMode);
    const nextMode = modes[(currentIndex + 1) % modes.length];
    setMergeMode(nextMode);
  }

  // Event Listeners
  els.fileInput1.addEventListener('change', (e) => {
    if (e.target.files[0]) loadImage(e.target.files[0], 0);
  });

  els.fileInput2.addEventListener('change', (e) => {
    if (e.target.files[0]) loadImage(e.target.files[0], 1);
  });

  els.settingsBtn.addEventListener('click', () => {
    els.settingsPanel.classList.toggle('show');
    resetAutoHide();
  });

  els.clearBtn.addEventListener('click', clearImages);

  els.toggleModeBtn.addEventListener('click', cycleMode);

  els.downloadBtn.addEventListener('click', downloadImage);

  // Merge settings
  els.spacingSlider.addEventListener('input', (e) => {
    state.spacing = parseInt(e.target.value);
    els.spacingValue.textContent = state.spacing;
    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  });

  els.colorPicker.addEventListener('input', (e) => {
    state.backgroundColor = e.target.value;
    els.colorText.value = e.target.value;
    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  });

  els.colorText.addEventListener('input', (e) => {
    state.backgroundColor = e.target.value;
    els.colorPicker.value = e.target.value;
    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  });

  // Overlay settings
  els.offsetXSlider.addEventListener('input', (e) => {
    state.offsetX = parseInt(e.target.value);
    els.offsetXValue.textContent = state.offsetX;
    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  });

  els.offsetYSlider.addEventListener('input', (e) => {
    state.offsetY = parseInt(e.target.value);
    els.offsetYValue.textContent = state.offsetY;
    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  });

  els.scaleSlider.addEventListener('input', (e) => {
    state.scale = parseInt(e.target.value);
    els.scaleValue.textContent = state.scale;
    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  });

  els.opacitySlider.addEventListener('input', (e) => {
    state.opacity = parseInt(e.target.value);
    els.opacityValue.textContent = state.opacity;
    if (state.images[0] && state.images[1]) {
      composeImages();
    }
  });

  // Position buttons
  document.querySelectorAll('.position-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      state.overlayPosition = btn.dataset.position;
      document.querySelectorAll('.position-btn').forEach(b => {
        b.classList.remove('active');
      });
      btn.classList.add('active');
      if (state.images[0] && state.images[1]) {
        composeImages();
      }
    });
  });

  // Mode buttons
  document.querySelectorAll('.mode-btn').forEach(btn => {
    btn.addEventListener('click', () => setMergeMode(btn.dataset.mode));
  });

  // Touch and mouse events for auto-hide
  document.addEventListener('touchstart', resetAutoHide);
  document.addEventListener('mousemove', resetAutoHide);

  // Initialize
  updatePreview(0);
  updatePreview(1);
  resetAutoHide();
});
