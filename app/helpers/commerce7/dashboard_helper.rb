module Commerce7
  module DashboardHelper
    TREND_CHART_WIDTH = 600
    TREND_CHART_HEIGHT = 120
    TREND_CHART_PADDING = 16

    # Scales a series of TenantMetricSnapshot values to fit the fixed trend
    # chart viewBox. Flat data (every value equal, or a single point) still
    # renders a centered flat line rather than dividing by zero.
    def trend_chart_points(snapshots, value_method)
      return [] if snapshots.empty?

      values = snapshots.map { |snapshot| snapshot.public_send(value_method) }
      min = values.min
      range = (values.max - min).nonzero? || 1
      plot_width = TREND_CHART_WIDTH - (2 * TREND_CHART_PADDING)
      plot_height = TREND_CHART_HEIGHT - (2 * TREND_CHART_PADDING)
      step = snapshots.size > 1 ? plot_width / (snapshots.size - 1).to_f : 0

      snapshots.each_with_index.map do |snapshot, index|
        value = snapshot.public_send(value_method)
        x = snapshots.size > 1 ? TREND_CHART_PADDING + (index * step) : TREND_CHART_WIDTH / 2.0
        y = TREND_CHART_HEIGHT - TREND_CHART_PADDING - (((value - min) / range.to_f) * plot_height)
        { x: x.round(1), y: y.round(1), snapshot: snapshot, value: value }
      end
    end
  end
end
