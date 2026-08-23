import { Chart, registerables } from "chart.js"
Chart.register(...registerables)

// Semantic status colours, mirroring the design tokens in assets/css/app.css
// (--color-success / -warning / -danger / slate-500). Chart.js cannot read CSS
// custom properties, so these are duplicated here — keep them in step.
const STATUS_COLORS = ["#059669", "#D97706", "#DC2626", "#64748B"]

// Payment providers. Two today (Paystack, Hubtel); extend positionally.
const PROVIDER_COLORS = ["#059669", "#2563EB", "#D97706", "#64748B"]

const CHART_CONFIGS = {
  // Payments: one bar per status, each carrying its own meaning-colour.
  // Unlike count-bar, the colour is positional — the labels arrive in a
  // fixed order (paid / waiting / failed / sent back).
  "status-bar": (data) => ({
    type: "bar",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        backgroundColor: STATUS_COLORS,
        borderRadius: 8,
        borderSkipped: false,
        maxBarThickness: 64
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 12 } } },
        y: {
          beginAtZero: true,
          grid: { color: "rgba(0,0,0,0.05)" },
          ticks: { font: { size: 11 }, precision: 0 }
        }
      }
    }
  }),

  // Payments: volume split by provider. The total and legend are rendered as
  // markup around the canvas, so the ring itself carries no text.
  "provider-donut": (data) => ({
    type: "doughnut",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        backgroundColor: PROVIDER_COLORS,
        borderWidth: 0,
        hoverOffset: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: "68%",
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (item) => `${item.label}: GH₵ ${(item.raw / 100).toFixed(2)}`
          }
        }
      }
    }
  }),

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
            label: (item) => `GH₵ ${(item.raw / 100).toFixed(2)}`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 } } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          ticks: {
            font: { size: 11 },
            callback: (v) => `GH₵ ${(v / 100).toFixed(0)}`
          }
        }
      }
    }
  }),

  // Platform overview: GMV trend — emerald area, values in minor units.
  "gmv-line": (data) => ({
    type: "line",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        borderColor: "rgba(16, 185, 129, 0.9)",
        backgroundColor: "rgba(16, 185, 129, 0.1)",
        fill: true,
        tension: 0.3,
        pointRadius: 3,
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
            label: (item) => `GH₵ ${(item.raw / 100).toFixed(2)}`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 }, maxTicksLimit: 8 } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          beginAtZero: true,
          ticks: {
            font: { size: 11 },
            callback: (value) => `GH₵ ${(value / 100).toFixed(0)}`
          }
        }
      }
    }
  }),

  // Platform overview: new stores per week — blue bars, plain counts.
  "count-bar": (data) => ({
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
            label: (item) => `${item.raw}`
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
