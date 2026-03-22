const Analytics = {
  mounted() {
    this.handleEvent("track", ({event, props}) => {
      // Fire Plausible custom event if available
      if (window.plausible) {
        window.plausible(event, {props: props || {}});
      }
    });
  }
};

export default Analytics;
