module SPD
  module Config
    module LoadableByEval
      def load_from_disk(path)
        SPD::Common::FileOps.eval_file(path, self)
      end
    end
  end
end