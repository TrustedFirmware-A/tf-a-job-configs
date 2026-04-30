def commitlint(Map args) {
    [
        job: 'tf-a-commitlint',

        parameters: [
            string(name: 'URL', value: "https://review.trustedfirmware.org/${args.project}"),

            string(name: 'REFSPEC', value: args.refspec),
            string(name: 'REFNAME', value: args.refname),
            string(name: 'REFNAME_BASE', value: args.refnameBase),
        ],
    ]
}
