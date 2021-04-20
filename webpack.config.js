const path = require('path');
const webpack = require('webpack');

module.exports = {
  entry: './root/static/js/canto-modules.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'root/dist'),
  },
  mode: 'development',
  resolve: {
    alias: {
      'tag-it': path.resolve(__dirname, 'root/static/js/tag-it.js')
    }
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader']
      },
      {
        test: /\.woff($|\?)|\.woff2($|\?)|\.ttf($|\?)|\.eot($|\?)|\.svg($|\?)/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: '[name].[ext]',
              outputPath: 'fonts/'
            }
          }
        ]
      }
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
      'window.jQuery': 'jquery'
    })
  ],
  devtool: "source-map"
};
