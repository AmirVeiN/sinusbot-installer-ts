registerPlugin(
  {
    name: "Auto Rejoin (Anti-Flood)",
    version: "1.5",
    description:
      "Staggered reconnect intervals to bypass TeamSpeak join limits.",
    author: "Custom Script",
    vars: {
      checkInterval: {
        title: "Check Interval (seconds - recommended: 30 or higher)",
        type: "number",
        default: 30,
      },
    },
  },
  function (sinusbot, config) {
    var backend = require("backend");
    var engine = require("engine");

    var checkInterval = (parseInt(config.checkInterval) || 30) * 1000;

    var randomOffset = Math.floor(Math.random() * 15000);

    engine.log(
      "Auto Rejoin loaded. Starting connection monitor in " +
        randomOffset / 1000 +
        " seconds...",
    );

    setTimeout(function () {
      engine.log("Connection monitor active.");

      setInterval(function () {
        if (!backend) return;

        if (!backend.isConnected()) {
          engine.log(
            "Bot connection lost (Flood limit or server offline). Retrying connection now...",
          );
          backend.connect();
        }
      }, checkInterval);
    }, randomOffset);
  },
);
