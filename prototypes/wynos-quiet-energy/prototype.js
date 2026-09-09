const device = document.querySelector('#device');
const stateButton = document.querySelector('#stateButton');

function showScreen(id) {
  document.querySelectorAll('.screen').forEach((screen) => {
    screen.classList.toggle('is-active', screen.id === id);
  });
  document.querySelectorAll('[data-screen]').forEach((button) => {
    button.classList.toggle('is-active', button.dataset.screen === id);
  });
  document.querySelector('.bottom-nav').hidden = id === 'system';
}

document.querySelectorAll('[data-screen]').forEach((button) => {
  button.addEventListener('click', () => showScreen(button.dataset.screen));
});

document.querySelectorAll('[data-viewport]').forEach((button) => {
  button.addEventListener('click', () => {
    device.className = `device ${button.dataset.viewport}`;
    document.querySelectorAll('[data-viewport]').forEach((item) => {
      item.classList.toggle('is-active', item === button);
    });
  });
});

stateButton.addEventListener('click', () => {
  const loading = device.classList.toggle('is-loading');
  stateButton.textContent = loading ? 'แสดง Loaded state' : 'แสดง Loading state';
});
