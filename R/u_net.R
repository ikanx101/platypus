#' Creates a double convolutional U-Net block.
#' @description Creates a double convolutional U-Net block.
#' @import keras
#' @importFrom magrittr %>%
#' @importFrom purrr when
#' @param input Model or layer object.
#' @param filters Integer, the dimensionality of the output space (i.e. the number of output filters in the convolution).
#' @param kernel_size An integer or list of 2 integers, specifying the width and height of the 2D convolution window. Can be a single integer to specify the same value for all spatial dimensions.
#' @param batch_normalization Should batch normalization be used in the block.
#' @param kernel_initializer Initializer for the kernel weights matrix.
#' @return Double convolutional U-Net block.
u_net_double_conv2d <- function(input, filters, kernel_size, batch_normalization = TRUE, kernel_initializer = "he_normal") {
  input %>%
    layer_conv_2d(filters = filters, kernel_size = kernel_size,
                  padding = "same", kernel_initializer = kernel_initializer) %>%
    when(batch_normalization ~ layer_batch_normalization(.), ~ .) %>%
    layer_activation_relu() %>%
    layer_conv_2d(filters = filters, kernel_size = kernel_size,
                  padding = "same", kernel_initializer = kernel_initializer) %>%
    when(batch_normalization ~ layer_batch_normalization(.), ~ .) %>%
    layer_activation_relu()
}

#' Creates a U-Net architecture.
#' @description Creates a U-Net architecture.
#' @import keras
#' @importFrom magrittr %>%
#' @importFrom purrr when
#' @param net_h Input layer height. Must be equal to `2^x, x - natural`..
#' @param net_w Input layer width. Must be equal to `2^x, x - natural`.
#' @param grayscale Defines input layer color channels -  `1` if `TRUE`, `3` if `FALSE`.
#' @param blocks Number of blocks in the model.
#' @param n_class Number of classes. Minimum is `2` (background + other object).
#' @param filters Integer, the dimensionality of the output space (i.e. the number of output filters in the convolution).
#' @param dropout Dropout rate.
#' @param batch_normalization Should batch normalization be used in the block.
#' @param kernel_initializer Initializer for the kernel weights matrix.
#' @return U-Net model.
#' @export
u_net <- function(net_h, net_w, grayscale, blocks = 4, n_class = 2, filters = 16,
                  dropout = 0.1, batch_normalization = TRUE, kernel_initializer = "he_normal") {
  u_net_check(net_h, net_w, grayscale, blocks, n_class, filters, dropout, batch_normalization)
  channels <- if (grayscale) 1 else 3
  input_shape <- c(net_h, net_w, channels)
  input_img <- layer_input(shape = input_shape, name = 'input_img')

  conv_layers <- pool_layers <- conv_tr_layers <- list()

  for (block in 1:blocks) {
    current_input <- if (block == 1) input_img else pool_layers[[block - 1]]
    conv_layers[[block]] <- u_net_double_conv2d(current_input, filters * 2^(block - 1), kernel_size = 3,
                                                batch_normalization = batch_normalization,
                                                kernel_initializer = kernel_initializer)
    pool_layers[[block]] <- layer_max_pooling_2d(conv_layers[[block]], pool_size = 2) %>%
      layer_dropout(rate = dropout)
  }

  conv_layers[[blocks + 1]] <- u_net_double_conv2d(pool_layers[[blocks]], filters * 2^blocks, kernel_size = 3,
                                                   batch_normalization = batch_normalization,
                                                   kernel_initializer = kernel_initializer)

  for (block in 1:blocks) {
    conv_tr_layers[[block]] <- layer_conv_2d_transpose(conv_layers[[blocks + block]], filters * 2^(blocks - block), kernel_size = 3,
                                                       strides = 2, padding = "same")
    conv_tr_layers[[block]] <- layer_concatenate(inputs = list(conv_tr_layers[[block]], conv_layers[[blocks - block + 1]])) %>%
      layer_dropout(rate = dropout)
    conv_layers[[blocks + block + 1]] <- u_net_double_conv2d(conv_tr_layers[[block]], filters * 2^(blocks - block), kernel_size = 3,
                                                             batch_normalization = batch_normalization,
                                                             kernel_initializer = kernel_initializer)
  }

  output <- layer_conv_2d(conv_layers[[2 * blocks + 1]], n_class, 1, activation = "softmax")
  keras_model(inputs = input_img, outputs = output)
}

#' `VOC` dataset labels.
#' @description `VOC` dataset labels.
#' @return `VOC` dataset labels.
#' @export
voc_labels <- c('background', 'aeroplane', 'bicycle', 'bird', 'boat',
                'bottle', 'bus', 'car', 'cat', 'chair', 'cow',
                'diningtable', 'dog', 'horse', 'motorbike', 'person',
                'potted plant', 'sheep', 'sofa', 'train', 'tv/monitor')

#' `VOC` dataset segmentation color map.
#' @description `VOC` dataset segmentation color map.
#' @return `VOC` dataset segmentation color map.
#' @export
voc_colormap <- list(c(0, 0, 0), c(128, 0, 0), c(0, 128, 0), c(128, 128, 0),
                c(0, 0, 128), c(128, 0, 128), c(0, 128, 128), c(128, 128, 128),
                c(64, 0, 0), c(192, 0, 0), c(64, 128, 0), c(192, 128, 0),
                c(64, 0, 128), c(192, 0, 128), c(64, 128, 128), c(192, 128, 128),
                c(0, 64, 0), c(128, 64, 0), c(0, 192, 0), c(128, 192, 0),
                c(0, 64, 128))

#' Binary segmentation color map.
#' @description Binary segmentation color map.
#' @return Binary segmentation color map.
#' @export
binary_colormap <- list(c(0, 0, 0), c(255, 255, 255))

#' Binary segmentation labels.
#' @description Binary segmentation labels.
#' @return Binary segmentation labels.
#' @export
binary_labels <- c('background', 'object')
