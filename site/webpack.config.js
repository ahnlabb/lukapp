var path = require('path');
const TerserPlugin = require('terser-webpack-plugin');

module.exports = {
  entry: {
      app: ['./index.js'],
  },

  output: {
    path: path.resolve(__dirname),
    filename: '[name].js',
  },

  module: {
    rules: [
      {
        test: /\.(css|scss)$/,
        use: ['style-loader', 'css-loader'],
      },
      {
        test: /\.html$/,
        exclude: /node_modules/,
        loader: 'file-loader?name=[name].[ext]',
      },
      {
      test: /\.elm$/,
      exclude: [/elm-stuff/, /node_modules/],
      use: {
          loader: 'elm-webpack-loader',
          options: {
              optimize: true
          }
        },
      },
      {
        test: /\.woff(2)?(\?v=[0-9]\.[0-9]\.[0-9])?$/,
        loader: 'url-loader?limit=10000&mimetype=application/font-woff',
      },
      {
        test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/,
        loader: 'file-loader',
      },
    ],

    noParse: /\.elm$/,
  },
  optimization: {
    minimizer: [
      // https://elm-lang.org/0.19.0/optimize
      new TerserPlugin({
        extractComments: false,
        terserOptions: {
          mangle: false,
          compress: {
            pure_funcs: ['F2','F3','F4','F5','F6','F7','F8','F9','A2','A3','A4','A5','A6','A7','A8','A9'],
            pure_getters: true,
            keep_fargs: false,
            unsafe_comps: true,
            unsafe: true,
          },
        },
      }),
      new TerserPlugin({
        extractComments: false,
        terserOptions: { mangle: true },
      }),
    ],
  },

  devServer: {
    inline: true,
    stats: {colors: true},
  },
};
