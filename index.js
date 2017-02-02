module.exports = {
  get Worker() {
    return require('./js/worker').default;
  }
};
