import { Chart, registerables } from "chart.js"
Chart.register(...registerables)

const CHART_CONFIGS = {
  "revenue-bar": (data) => ({
    type: "bar",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        backgroundColor: "rgba(59, 130, 246, 0.8)",
        borderRadius: 6,
        borderSkipped: false,
        maxBarThickness: 40
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => `GHS ${(item.raw / 100).toFixed(2)}`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 } } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          ticks: {
            font: { size: 11 },
            callback: (v) => `GHS ${(v / 100).toFixed(0)}`
          }
        }
      }
    }
  }),

  "orders-line": (data) => ({
    type: "line",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        borderColor: "rgba(16, 185, 129, 0.9)",
        backgroundColor: "rgba(16, 185, 129, 0.1)",
        fill: true,
        tension: 0.3,
        pointRadius: 4,
        pointHoverRadius: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => `${item.raw} orders`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 } } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          beginAtZero: true,
          ticks: { font: { size: 11 }, stepSize: 1 }
        }
      }
    }
  }),

  "top-products-horizontal": (data) => ({
    type: "bar",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        backgroundColor: [
          "rgba(59, 130, 246, 0.8)",
          "rgba(16, 185, 129, 0.8)",
          "rgba(245, 158, 11, 0.8)",
          "rgba(139, 92, 246, 0.8)",
          "rgba(236, 72, 153, 0.8)"
        ],
        borderRadius: 4,
        borderSkipped: false
      }]
    },
    options: {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (item) => `${item.raw} units sold`
          }
        }
      },
      scales: {
        x: { grid: { color: "rgba(0,0,0,0.05)" }, ticks: { font: { size: 11 }, stepSize: 1 } },
        y: { grid: { display: false }, ticks: { font: { size: 11 } } }
      }
    }
  }),

  "customers-line": (data) => ({
    type: "line",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        borderColor: "rgba(139, 92, 246, 0.9)",
        backgroundColor: "rgba(139, 92, 246, 0.1)",
        fill: true,
        tension: 0.3,
        pointRadius: 4,
        pointHoverRadius: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => `${item.raw} new customers`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 } } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          beginAtZero: true,
          ticks: { font: { size: 11 }, stepSize: 1 }
        }
      }
    }
  })
}

const ChartHook = {
  mounted() {
    const chartType = this.el.dataset.chartType
    const initialData = JSON.parse(this.el.dataset.chartData || '{"labels":[],"values":[]}')
    const configFn = CHART_CONFIGS[chartType]

    if (configFn) {
      this.chart = new Chart(this.el, configFn(initialData))
    }

    this.handleEvent(`chart-data:${this.el.id}`, ({ data }) => {
      if (this.chart && data) {
        this.chart.data.labels = data.labels
        this.chart.data.datasets[0].data = data.values
        this.chart.update("active")
      }
    })
  },

  updated() {
    const chartType = this.el.dataset.chartType
    const newData = JSON.parse(this.el.dataset.chartData || '{"labels":[],"values":[]}')
    if (this.chart && newData) {
      this.chart.data.labels = newData.labels
      this.chart.data.datasets[0].data = newData.values
      this.chart.update("active")
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}

export default ChartHook
