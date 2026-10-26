// Just enough of Safari's `browser` API for settings.js, content.js and
// popup.js to run in a plain page. Storage is shared between pages through
// window.__store when the test hands one in.
window.browser = (() => {
  const store = (window.__store ||= {});
  const listeners = [];
  const messageHandlers = [];
  const clone = (v) => (v === undefined ? v : JSON.parse(JSON.stringify(v)));
  return {
    storage: {
      local: {
        async get(key) {
          return key in store ? { [key]: clone(store[key]) } : {};
        },
        async set(items) {
          const changes = {};
          for (const [k, v] of Object.entries(items)) {
            changes[k] = { oldValue: clone(store[k]), newValue: clone(v) };
            store[k] = clone(v);
          }
          listeners.forEach((l) => l(changes, "local"));
        },
      },
      onChanged: { addListener: (f) => listeners.push(f) },
    },
    runtime: {
      onMessage: { addListener: (f) => messageHandlers.push(f) },
      __send: (message) =>
        new Promise((resolve) => messageHandlers.forEach((h) => h(message, {}, resolve))),
    },
    i18n: { getMessage: (k) => k },
    tabs: {
      async query() { return [{ id: 1 }]; },
      async sendMessage(_id, message) {
        if (!window.__pageUrl) throw new Error("no content script");
        return message.type === "wider:url" ? { url: window.__pageUrl } : undefined;
      },
    },
  };
})();
