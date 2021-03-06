Color = require('../util/color')

class Settings

  # Line Widths:
  @POST_RADIUS: 3
  @CURRENT_RADIUS: 3
  @LINE_WIDTH: 2

  # Grid
  @GRID_SIZE: 16
  @SMALL_GRID: false

  # Colors:
  @SELECT_COLOR: Color.ORANGE
  @POST_COLOR_SELECTED: Color.ORANGE
  @POST_COLOR: Color.BLACK
  @DOTS_COLOR: Color.YELLOW
  @DOTS_OUTLINE: Color.ORANGE

  @TEXT_COLOR: Color.BLACK
  @TEXT_ERROR_COLOR: Color.RED
  @TEXT_WARNING_COLOR: Color.YELLOW

  @SELECTION_MARQUEE_COLOR: Color.ORANGE

  @GRID_COLOR: Color.DEEP_YELLOW
  @BG_COLOR: Color.WHITE
  @FG_COLOR: Color.DARKGRAY
  @ERROR_COLOR: Color.DEEPRED
  @WARNING_COLOR: Color.ORANGE

module.exports = Settings