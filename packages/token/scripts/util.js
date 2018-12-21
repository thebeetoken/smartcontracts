module.exports = {
    promisify: function promisify(inner) {
        return new Promise((resolve, reject) =>
            inner((err, res) => {
                if (err) { return reject(err); }

                resolve(res);
            })
        );
    },
};