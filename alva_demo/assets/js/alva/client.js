import { use_alva_api } from "alva/use_alva_api";
const base_api = use_alva_api();
function create_deep_proxy(path = []) {
    return new Proxy(() => { }, {
        get(_target, prop) {
            return create_deep_proxy([...path, prop]);
        },
        apply(_target, _this_arg, args) {
            const event_name = path.join('.');
            const ash_call = base_api.call;
            return ash_call(event_name, args[0]);
        }
    });
}
export const api = create_deep_proxy();
