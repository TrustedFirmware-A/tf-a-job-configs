def withContainer(Map args, Closure body) {
    args = [name: 'container'] + args

    podTemplate(containers: [containerTemplate(args)]) {
        node(POD_LABEL) {
            body(args.name)
        }
    }
}
